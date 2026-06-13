#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsDispatch
 *
 * Dispatch one trip for the given route. Shared between the
 * scheduler tick and the manual "Dispatch Now" button.
 *
 * Cargo handling (STRIP-AND-UNPACK at dispatch time):
 *
 *   WEAPONS: snapshotted via weaponsItemsCargo to capture each
 *     weapon's full configuration (attachments + pre-loaded mags).
 *     On dispatch the *bare* weapon class goes into the weapons
 *     bucket, the optic/suppressor/etc. attachments are extracted
 *     into the items bucket, and the pre-loaded mags are extracted
 *     into the mags bucket. The destination receives a bare gun
 *     plus its attachments and mags as loose cargo, not a kitted
 *     gun. That's the user's stated preference: "guns attachments
 *     get put into the container instead".
 *
 *   BACKPACKS: snapshotted via everyContainer (filtered to Bag_Base
 *     descendants) so we can read each bag's contents. On dispatch
 *     the bag CLASS goes into the backpacks bucket (empty), and the
 *     contents (weapons / mags / items) are extracted into their
 *     respective buckets. The destination receives empty bags plus
 *     their old contents as loose cargo.
 *
 *   MAGAZINES + ITEMS: consolidated [[cls],[counts]] via getX cargo.
 *     Partial-ammo magazines lose their partial count (treated as
 *     full); acceptable for almost all logistics scenarios.
 *
 * Source-side removal:
 *   - clearWeaponCargoGlobal wipes every weapon (bare or kitted);
 *     we re-add the keep-list with addWeaponWithAttachmentsCargoGlobal
 *     so weapons that stay at source retain their kit.
 *   - CBA_fnc_removeMagazineCargo / removeItemCargo remove the raw
 *     cargo amounts we're moving (NOT counting extras extracted from
 *     weapons or bags -- those were never in cargo).
 *   - CBA_fnc_removeBackpackCargo removes the move-list bag classes;
 *     the bag's contents leave the world with the bag instance and
 *     are reborn at the destination as the extras we extracted.
 *
 * Payload structure (in BO_logisticsActiveDeliveries):
 *   _payload = [_weapons, _magazines, _items, _backpacks]
 *   each = [[cls, qty], ...] consolidated.
 *
 * Scalability: the consolidated buckets are O(unique classes).
 * Weapon iteration is O(weapons in source) -- each can have unique
 * attachments so we can't pre-consolidate, but the extras get
 * consolidated before storage so the payload is still O(unique).
 */

if (!isServer) exitWith { "not_server" };

params [["_route", [], [[]]]];

_route params [
    "_routeId", "_ownerUID", "_srcId", "_dstId",
    "_items", "_qtyPerTrip",
    "_schedule", "_fee", "_paused", "_stats", "_skipIfEmpty"
];

private _ownerObj = (allPlayers select { getPlayerUID _x == _ownerUID }) param [0, objNull];

private _notifyOwner = {
    params ["_msg"];
    if (!isNull _ownerObj) then {
        _msg remoteExec ["OT_fnc_notifyMinor", _ownerObj, false];
    };
};

private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;

if (isNull _src) exitWith {
    private _m = format ["Logistics dispatch failed: source missing (route %1)", _routeId];
    [AUDIT_LOGISTICS, _m, [_routeId], _ownerUID, ""] call BO_fnc_auditServer;
    ["Logistics: source container missing -- route paused"] call _notifyOwner;
    "src_missing"
};
if (isNull _dst) exitWith {
    private _m = format ["Logistics dispatch failed: destination missing (route %1)", _routeId];
    [AUDIT_LOGISTICS, _m, [_routeId], _ownerUID, ""] call BO_fnc_auditServer;
    ["Logistics: destination container missing -- route paused"] call _notifyOwner;
    "dst_missing"
};

// --- Snapshots --------------------------------------------------------
private _srcWfull = weaponsItemsCargo _src;
private _srcM     = getMagazineCargo  _src;
private _srcI     = getItemCargo      _src;
private _srcContainers = everyContainer _src;
private _srcBags = _srcContainers select { ((_x select 1) isKindOf "Bag_Base") };

private _remaining = if (_qtyPerTrip < 0) then { -1 } else { _qtyPerTrip };

// Consolidator: turn a flat [cls, cls, cls, ...] list into [[cls, qty], ...]
private _consolidate = {
    params ["_flat"];
    private _out = [];
    {
        private _cls = _x;
        if (_cls isEqualTo "") then { continue };
        private _idx = _out findIf { (_x select 0) isEqualTo _cls };
        if (_idx >= 0) then {
            (_out select _idx) set [1, ((_out select _idx) select 1) + 1];
        } else {
            _out pushBack [_cls, 1];
        };
    } forEach _flat;
    _out
};

// Merge two [[cls, qty], ...] buckets into one (summing counts on
// matching classes).
private _mergeBuckets = {
    params ["_a", "_b"];
    private _out = +_a;
    {
        private _cls = _x select 0;
        private _qty = _x select 1;
        private _idx = _out findIf { (_x select 0) isEqualTo _cls };
        if (_idx >= 0) then {
            (_out select _idx) set [1, ((_out select _idx) select 1) + _qty];
        } else {
            _out pushBack [_cls, _qty];
        };
    } forEach _b;
    _out
};

// --- WEAPONS: classify, strip attachments/mags from move list -------
private _moveBareWeapons = []; // flat list of bare classnames
private _moveAttachments = []; // attachments extracted from moved weapons
private _moveLoadedMags  = []; // mags extracted from moved weapons
private _keepW           = []; // full configs to restore at source
{
    private _wcls    = _x select 0;
    private _baseCls = _wcls call BIS_fnc_baseWeapon;
    private _matches = (_items isEqualTo []) || { _wcls in _items } || { _baseCls in _items };

    if ((!_matches) || (_remaining isEqualTo 0)) then {
        _keepW pushBack _x;
    } else {
        _moveBareWeapons pushBack _wcls;
        // Attachments live at indices 1 (muzzle), 2 (flash), 3 (optic),
        // 6 (underbarrel). Each is a classname string or "" if empty.
        {
            if (_x isNotEqualTo "") then { _moveAttachments pushBack _x };
        } forEach [_x select 1, _x select 2, _x select 3, _x select 6];
        // Pre-loaded mags at indices 4 (primary [cls, ammo]) and 5
        // (secondary [cls, ammo]).
        {
            if ((count _x) > 0 && {(_x select 0) isNotEqualTo ""}) then {
                _moveLoadedMags pushBack (_x select 0);
            };
        } forEach [_x select 4, _x select 5];

        if (_remaining > 0) then { _remaining = _remaining - 1 };
    };
} forEach _srcWfull;

// --- MAGS / ITEMS from raw cargo ------------------------------------
private _extract = {
    params ["_cargo", "_filter", "_budget"];
    private _out = [];
    _cargo params [["_classes", []], ["_counts", []]];
    private _b = _budget;
    {
        if (_b isEqualTo 0) exitWith {};
        private _cls = _x;
        if (_filter isNotEqualTo [] && { !(_cls in _filter) }) then { continue };
        private _have = _counts param [_forEachIndex, 0];
        private _take = if (_b < 0) then { _have } else { _have min _b };
        if (_take > 0) then {
            _out pushBack [_cls, _take];
            if (_b >= 0) then { _b = _b - _take };
        };
    } forEach _classes;
    [_out, _b]
};

([_srcM, _items, _remaining] call _extract) params ["_payloadM_raw", "_remaining"];
([_srcI, _items, _remaining] call _extract) params ["_payloadI_raw", "_remaining"];

// --- BACKPACKS: per-bag, snapshot contents, mark bag for removal ----
private _moveBagClasses  = []; // flat list for consolidation
private _moveBagWeapons  = []; // bare classnames pulled from inside bags
private _moveBagMags     = [];
private _moveBagItems    = [];

{
    _x params ["_bagCls", "_bagObj"];
    private _matches = (_items isEqualTo []) || { _bagCls in _items };

    if ((!_matches) || (_remaining isEqualTo 0)) then {
        // leave the bag alone
    } else {
        _moveBagClasses pushBack _bagCls;
        // Bag contents (the weapon array here is bare classnames --
        // weaponsItemsCargo on a bag inherits engine quirks; we accept
        // bare for bag-internal weapons. Most kitted weapons live in
        // the cargo directly, not stuffed inside a bag in the crate).
        { _moveBagWeapons pushBack _x } forEach (weaponCargo _bagObj);
        { _moveBagMags    pushBack _x } forEach (magazineCargo _bagObj);
        { _moveBagItems   pushBack _x } forEach (itemCargo _bagObj);

        if (_remaining > 0) then { _remaining = _remaining - 1 };
    };
} forEach _srcBags;

// --- Build final payload buckets ------------------------------------
private _payloadW = [
    [_moveBareWeapons + _moveBagWeapons] call _consolidate,
    []
] call _mergeBuckets;

private _extrasI = [_moveAttachments + _moveBagItems] call _consolidate;
private _extrasM = [_moveLoadedMags + _moveBagMags] call _consolidate;

private _payloadM = [_payloadM_raw, _extrasM] call _mergeBuckets;
private _payloadI = [_payloadI_raw, _extrasI] call _mergeBuckets;
private _payloadB = [_moveBagClasses] call _consolidate;

private _totalUnits = 0;
{ _totalUnits = _totalUnits + (_x select 1) } forEach (_payloadW + _payloadM + _payloadI + _payloadB);

if (_totalUnits isEqualTo 0 && _skipIfEmpty) exitWith {
    private _m = format ["Logistics: source empty, route %1 skipped", _routeId];
    [AUDIT_LOGISTICS, _m, [_routeId], _ownerUID, ""] call BO_fnc_auditServer;
    ["Logistics: source container has no matching items -- route skipped"] call _notifyOwner;
    "empty"
};

// Fee check (online or offline)
private _bank = if (!isNull _ownerObj) then {
    _ownerObj getVariable ["BO_bank", 0]
} else {
    [_ownerUID, "BO_bank", 0] call OT_fnc_getOfflinePlayerAttribute
};

if (_bank < _fee) exitWith {
    private _m = format ["Logistics: insufficient funds (route %1, need $%2, have $%3)", _routeId, _fee, _bank];
    [AUDIT_LOGISTICS, _m, [_routeId, _fee, _bank], _ownerUID, ""] call BO_fnc_auditServer;
    private _msg = format ["Logistics: route fee $%1 exceeds bank balance $%2 -- deposit at an ATM", _fee, _bank];
    [_msg] call _notifyOwner;
    "insufficient"
};

// --- Apply removal at source ----------------------------------------
// Weapons: clear all, restore keep-list with attachments. The moved
// weapons + their attachments + their loaded mags all vanish here.
clearWeaponCargoGlobal _src;
{ _src addWeaponWithAttachmentsCargoGlobal [_x, 1] } forEach _keepW;

// Backpacks: removing the bag class also disposes of its contents.
// We've already snapshotted those into the move payload.
{ [_src, _x select 0, _x select 1] call CBA_fnc_removeBackpackCargo } forEach _payloadB;

// Mags + items from raw cargo: typed CBA remove of the raw quantities
// only (the extras came from weapons/bags and have already been
// removed by the operations above).
{ [_src, _x select 0, _x select 1] call CBA_fnc_removeMagazineCargo } forEach _payloadM_raw;
{ [_src, _x select 0, _x select 1] call CBA_fnc_removeItemCargo     } forEach _payloadI_raw;

// Deduct fee
if (!isNull _ownerObj) then {
    _ownerObj setVariable ["BO_bank", _bank - _fee, true];
} else {
    [_ownerUID, "BO_bank", _bank - _fee] call OT_fnc_setOfflinePlayerAttribute;
};

// Queue active delivery
([_src, _dst] call BO_fnc_logisticsTravelTime) params ["_travelSec", "_actualFee", "_distM"];
private _now = serverTime;
private _deliveryId = format ["d_%1_%2", round diag_tickTime, round (random 999999)];

private _payload = [_payloadW, _payloadM, _payloadI, _payloadB];

private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];
_deliveries pushBack [
    _deliveryId,
    _routeId,
    _now,                  // start
    _now + _travelSec,     // eta
    _payload,
    _srcId,
    _dstId,
    _ownerUID
];
server setVariable ["BO_logisticsActiveDeliveries", _deliveries, true];

private _logMsg = format ["Logistics dispatched: route %1, %2 units (W:%3 M:%4 I:%5 B:%6), ETA %7s, fee $%8",
    _routeId, _totalUnits,
    count _payloadW, count _payloadM, count _payloadI, count _payloadB,
    round _travelSec, _fee];
[AUDIT_LOGISTICS, _logMsg, [_routeId, _deliveryId, _totalUnits, round _travelSec, _fee], _ownerUID, ""] call BO_fnc_auditServer;

if (!isNull _ownerObj) then {
    private _note = format ["Dispatch: %1 units en route, ETA %2 min", _totalUnits, round (_travelSec / 60)];
    _note remoteExec ["OT_fnc_notifyMinor", _ownerObj, false];
};

"ok"
