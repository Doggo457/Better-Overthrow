#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garageStore
 *
 * Server-authoritative: snapshot a vehicle's full condition into the
 * persistent BO_garage list, delete the live vehicle, audit, debit
 * storage fee from the player's bank.
 *
 * Intended call site:
 *   [_veh, getPlayerUID player, name player, _warehouse] remoteExec
 *       ["BO_fnc_garageStore", 2, false];
 *
 * Params:
 *   0: OBJECT - vehicle to store
 *   1: STRING - caller UID
 *   2: STRING - caller display name
 *   3: OBJECT - the warehouse object granting capacity / pad
 *
 * Returns: BOOL - true on success, false on capacity/validation failure.
 */

SERVER_ONLY_RET(false);

params [
    ["_veh", objNull, [objNull]],
    ["_callerUID", "", [""]],
    ["_callerName", "", [""]],
    ["_warehouse", objNull, [objNull]]
];

if (isNull _veh || {!alive _veh} || {isNull _warehouse}) exitWith { false };

// Ownership gate (MP): the warehouse dialog lists EVERY nearby vehicle,
// so without this any player could store -- and later retrieve-to-own --
// someone else's ride. Storable: your own vehicle, unowned/NATO
// (captured), or anything if you're a General.
private _vehOwner = if (_veh call OT_fnc_hasOwner) then { _veh call OT_fnc_getOwner } else { "" };
private _isGeneralCaller = _callerUID in (server getVariable ["generals", []]);
if (_vehOwner isNotEqualTo "" && {_vehOwner isNotEqualTo "NATO"}
    && {_vehOwner isNotEqualTo _callerUID} && {!_isGeneralCaller}) exitWith {
    "That vehicle belongs to another player" remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    false
};

private _ownedWh = warehouse getVariable ["owned", []];
private _slotsPer = ["bo_garage_slots_per_warehouse", 5] call BIS_fnc_getParamValue;
private _capacity = (count _ownedWh) * _slotsPer;
private _garage = server getVariable ["BO_garage", []];
private _generalsExempt = (["bo_garage_generals_exempt", 1] call BIS_fnc_getParamValue) isEqualTo 1;
private _isGeneral = _isGeneralCaller;

if (count _garage >= _capacity && {!(_isGeneral && _generalsExempt)}) exitWith {
    "Garage is full -- capture more warehouses" remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    false
};

// Storage fee. BO_fnc_resolvePrice returns [base, wood, steel, plastic]
// -- we only want the cash base for fee math. Floor at $500 so cheap
// scrap doesn't get a free ride past the money-sink intent.
private _cls = typeOf _veh;
private _priceTuple = [_cls] call BO_fnc_resolvePrice;
private _baseVal = (_priceTuple select 0) max 500;
private _feeRate = ["bo_garage_store_fee_pct", 5] call BIS_fnc_getParamValue;
private _fee = round (_baseVal * (_feeRate / 100));
// NOTE: fee is debited at the END, after the record is committed --
// the old order charged the player even when a later snapshot step
// threw (charge-on-success).

// Condition snapshot -- mirrors fn_saveGame.sqf slot-7 layout so the
// retrieval restore code path looks familiar.
private _hp = getAllHitPointsDamage _veh;
// Legacy single-turret field kept for record compatibility; the full
// per-turret magazine state rides condition slot 10 (every turret:
// commander, FFV seats, pylons -- [mag, turretPath, ammoCount]).
private _ammo = (_veh weaponsTurret [0]) apply { [_x, _veh ammo _x] };
private _turretMags = magazinesAllTurrets _veh apply { [_x select 0, _x select 1, _x select 2] };
private _att = [];
private _aclass = _veh getVariable ["OT_attachedClass", ""];
private _aobj   = _veh getVariable ["OT_attachedWeapon", objNull];
if ((_aclass isNotEqualTo "") && {alive _aobj}) then {
    _att = [_aclass, (_aobj weaponsTurret [0]) apply { [_x, _aobj ammo _x] }];
};
private _cargo = _veh call OT_fnc_unitStock;
private _textures = getObjectTextures _veh;
// ACE cargo: getCargo returns live OBJECT references. The record gets
// persisted, where object refs die -- and deleteVehicle on the parent
// does NOT delete ACE-loaded cargo objects (they'd leak, hidden, for
// the rest of the campaign). Snapshot the CLASSNAMES (loadItem accepts
// a classname) and delete the physical cargo objects with the vehicle.
private _aceCargoObjs = if (!isNil "ace_cargo_fnc_getCargo") then {
    [_veh] call ace_cargo_fnc_getCargo
} else { [] };
private _aceCargo = (_aceCargoObjs select { !isNull _x }) apply { typeOf _x };
// Lint-class fix: this read was unguarded -- without ace_refuel loaded
// the store crashed AFTER taking the fee.
private _aceFuel = if (!isNil "ace_refuel_fnc_getFuel") then {
    _veh call ace_refuel_fnc_getFuel
} else { -1 };

private _condition = [
    fuel _veh,
    _hp,
    _aceFuel,
    _veh getVariable ["OT_locked", false],
    _ammo,
    _att,
    _cargo,
    _textures,
    _aceCargo,
    [vectorDir _veh, vectorUp _veh],
    _turretMags
];

private _garageId = format ["veh-%1-%2", diag_tickTime, floor (random 999999)];
private _insured  = _veh getVariable ["BO_insured", false];
private _premium  = _veh getVariable ["BO_insurancePremium", 0];
private _payoutTgt = _veh getVariable ["BO_insurancePayoutTarget", _callerUID];
private _captured = !(_veh call OT_fnc_hasOwner) || {(_veh call OT_fnc_getOwner) isEqualTo "NATO"};
private _dispName = _veh getVariable ["BO_garageNickname", ""];

private _record = [
    _garageId,
    _cls,
    _payoutTgt,
    _callerName,
    _insured,
    _premium,
    _condition,
    _dispName,
    serverTime,
    _captured,
    // slot 10: storer UID -- retrieval ownership gate (captured
    // vehicles stay communal). slot 11: insured value AT POLICY TIME,
    // so a later price change can't shift the payout.
    _callerUID,
    _veh getVariable ["BO_insuranceValueAtPolicy", _baseVal]
];

// Flag BEFORE pushBack so a save firing between push and delete
// excludes the live vehicle from the vehicles snapshot (the
// fn_saveGame.sqf _tocheck filter checks BO_storingInProgress).
_veh setVariable ["BO_storingInProgress", true, true];
_garage pushBack _record;
server setVariable ["BO_garage", _garage, true];

private _auditMsg = format ["Stored %1 (id=%2, captured=%3, insured=%4)", _cls, _garageId, _captured, _insured];
[AUDIT_GARAGE, _auditMsg, [_garageId, _cls, _captured, _insured, _fee], _callerUID, _callerName] call BO_fnc_auditServer;

// Charge-on-success: record is committed, safe to take the fee now.
if (_fee > 0) then {
    [_callerUID, -_fee, format ["Garage store: %1", _cls]] call BO_fnc_bankAdjust;
};

// Physical ACE cargo objects don't ride deleteVehicle -- clean them up
// explicitly (their classnames live on in the record).
{ if (!isNull _x) then { deleteVehicle _x } } forEach _aceCargoObjs;
deleteVehicle _veh;

private _notify = format ["Vehicle stored ($%1 fee, %2/%3 slots used)", _fee, count _garage, _capacity];
_notify remoteExec ["OT_fnc_notifyMinor", remoteExecutedOwner, false];

true
