#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsArrive
 *
 * Deposit a delivery's payload at its destination. Called by the
 * scheduler tick when serverTime crosses the entry's etaTime.
 *
 * Payload structure (set by BO_fnc_logisticsDispatch):
 *   _payload = [_weapons, _magazines, _items, _backpacks]
 *   each = [[_cls, _qty], ...]
 *
 * Uses the typed *Global add functions so cargo is visible to every
 * client (the ungloballed CBA variants don't network-replicate on
 * dedicated). The four cargo types are physically distinct engine
 * arrays -- adding a weapon via addItemCargoGlobal would NOT put
 * it in the weapons array, so type-matched add is mandatory.
 *
 * Rollback: if the destination is gone, push the payload back to
 * the source (using the same typed-add functions). If source is
 * gone too, audit the loss and drop the payload.
 *
 * Backward-compat with the OLD flat payload format ([[cls, qty], ...]
 * mixed types) -- detect by element type and fall back to legacy
 * polymorphic add. Old deliveries from before the typed payload
 * change still arrive cleanly, with the original duplication bug,
 * but they at least finish.
 */

if (!isServer) exitWith {};

params [["_delivery", [], [[]]]];

_delivery params [
    "_deliveryId", "_routeId", "_startTime", "_etaTime",
    "_payload", "_srcId", "_dstId", "_ownerUID"
];

private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;

// Detect payload format. New format: [[wpns],[mags],[itms],[bags]]
// where each inner is an array (or empty). Old format: a flat array
// of [cls, qty] pairs where each cls is a STRING.
private _isNewFormat = false;
if (count _payload isEqualTo 4) then {
    private _first = _payload select 0;
    if (_first isEqualType [] && {(_first isEqualTo []) || {(_first select 0) isEqualType []}}) then {
        _isNewFormat = true;
    };
};

private _payloadW = [];
private _payloadM = [];
private _payloadI = [];
private _payloadB = [];

if (_isNewFormat) then {
    _payloadW = _payload select 0;
    _payloadM = _payload select 1;
    _payloadI = _payload select 2;
    _payloadB = _payload select 3;
} else {
    // Legacy format -- treat everything as items.
    _payloadI = _payload;
};

// Weapons count: one entry = one weapon when using the
// with-attachments format; for the legacy [cls, qty] format
// (still possible during a mid-upgrade in-flight delivery)
// the second element is the count.
private _totalUnits = 0;
{
    if (_x isEqualType [] && {count _x >= 7} && {(_x select 1) isEqualType ""}) then {
        _totalUnits = _totalUnits + 1;
    } else {
        _totalUnits = _totalUnits + (_x select 1);
    };
} forEach _payloadW;
{ _totalUnits = _totalUnits + (_x select 1) } forEach (_payloadM + _payloadI + _payloadB);

// Target = dst if alive, else fall back to source for rollback.
private _target = _dst;
private _rolledBack = false;
if (isNull _target) then {
    private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
    if (!isNull _src) then {
        _target = _src;
        _rolledBack = true;
    };
};

if (isNull _target) exitWith {
    private _m = format ["Logistics: route %1 destination AND source gone, %2 units lost", _routeId, _totalUnits];
    [AUDIT_MISSION, _m, [_routeId, _deliveryId, _totalUnits], _ownerUID, ""] call BO_fnc_auditServer;
};

// Typed deposit. The *Global variants ensure MP visibility.
// Weapons in the new format are full configurations (attachments
// + pre-loaded mags preserved) -- use addWeaponWithAttachmentsCargoGlobal.
// Backward-compat: old payloads stored weapons as [cls, qty] pairs;
// detect by element shape and fall back to bare-weapon add for those.
{
    if (_x isEqualType [] && {count _x >= 7} && {(_x select 1) isEqualType ""}) then {
        // Full config: [wpn, muzzle, flash, optic, [pMag, ammo], [sMag, sAmmo], underbarrel]
        _target addWeaponWithAttachmentsCargoGlobal [_x, 1];
    } else {
        // Legacy [cls, qty] pair from pre-attachment-fix deliveries.
        _target addWeaponCargoGlobal [_x select 0, _x select 1];
    };
} forEach _payloadW;
{ _target addMagazineCargoGlobal [_x select 0, _x select 1] } forEach _payloadM;
{ _target addItemCargoGlobal     [_x select 0, _x select 1] } forEach _payloadI;
{ _target addBackpackCargoGlobal [_x select 0, _x select 1] } forEach _payloadB;

private _audit = if (_rolledBack) then {
    format ["Logistics: destination gone, route %1 payload returned to source (%2 units)", _routeId, _totalUnits]
} else {
    format ["Logistics delivered: route %1, %2 units at destination (W:%3 M:%4 I:%5 B:%6)",
        _routeId, _totalUnits,
        count _payloadW, count _payloadM, count _payloadI, count _payloadB]
};
[AUDIT_MISSION, _audit, [_routeId, _deliveryId, _totalUnits], _ownerUID, ""] call BO_fnc_auditServer;

private _ownerObj = (allPlayers select { getPlayerUID _x == _ownerUID }) param [0, objNull];
if (!isNull _ownerObj) then {
    private _note = if (_rolledBack) then {
        format ["Delivery returned: %1 units back at source (destination gone)", _totalUnits]
    } else {
        format ["Delivery arrived: %1 units at destination", _totalUnits]
    };
    _note remoteExec ["OT_fnc_notifyGood", _ownerObj, false];
};
