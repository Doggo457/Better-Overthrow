#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garageRetrieve
 *
 * Server-authoritative: spawn a stored vehicle at the warehouse
 * retrieval pad, apply its saved condition, setOwner to the retriever,
 * delete the garage record, audit, debit retrieval fee.
 *
 * Intended call site:
 *   [_garageId, _warehouse, getPlayerUID player, name player]
 *       remoteExec ["BO_fnc_garageRetrieve", 2, false];
 *
 * Params:
 *   0: STRING - garageId of the record to retrieve
 *   1: OBJECT - warehouse object (for pad spawn position)
 *   2: STRING - caller UID (new owner + fee payer)
 *   3: STRING - caller display name (audit)
 *
 * Returns: OBJECT - the spawned vehicle, objNull on failure.
 */

SERVER_ONLY_RET(objNull);

params [
    ["_garageId", "", [""]],
    ["_warehouse", objNull, [objNull]],
    ["_callerUID", "", [""]],
    ["_callerName", "", [""]]
];

if (_garageId isEqualTo "" || {isNull _warehouse}) exitWith { objNull };

private _garage = server getVariable ["BO_garage", []];
private _idx = _garage findIf { (_x select 0) isEqualTo _garageId };
if (_idx < 0) exitWith {
    "Garage record not found" remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    objNull
};

private _record = _garage select _idx;
_record params [
    "_id",
    "_cls",
    "_origUID",
    "_origName",
    "_insured",
    "_prem",
    "_cond",
    "_disp",
    "_storedAt",
    "_captured"
];
// Appended slots (older saves lack them -- param defaults cover):
// 10 = storer UID, 11 = insured value at policy time.
private _storerUID = _record param [10, _origUID];
private _policyValue = _record param [11, 0];

// Ownership gate (MP): retrieval transfers ownership via setOwner, so
// an open list was a theft vector. Your own vehicles, captured (ex-
// NATO) communal stock, or General override only.
private _isGeneralCaller = _callerUID in (server getVariable ["generals", []]);
if (!_captured && {_storerUID isNotEqualTo ""} && {_storerUID isNotEqualTo _callerUID}
    && {!_isGeneralCaller}) exitWith {
    (format ["Stored by %1 -- only they (or a General) can retrieve it", _origName])
        remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    objNull
};

private _priceTuple = [_cls] call BO_fnc_resolvePrice;
private _baseVal = (_priceTuple select 0) max 500;
private _feeRate = ["bo_garage_retrieve_fee_pct", 3] call BIS_fnc_getParamValue;
private _fee = round (_baseVal * (_feeRate / 100));

// Resolve retrieval pad. Use the cached one if it still has room for
// this vehicle's bbox; otherwise recompute via findEmptyPosition and
// cache the result on the warehouse for next time.
private _pad = _warehouse getVariable ["BO_garageRetrievalSpot", []];
private _needsRecompute = (_pad isEqualTo []) || {
    private _probe = _pad findEmptyPosition [5, 0, _cls];
    _probe isEqualTo []
};
if (_needsRecompute) then {
    private _wpos = getPosATL _warehouse;
    _pad = _wpos findEmptyPosition [8, 50, _cls];
    if (_pad isEqualTo []) then {
        _pad = _warehouse getPos [12, (getDir _warehouse) + 90];
    };
    _warehouse setVariable ["BO_garageRetrievalSpot", _pad, true];
};

// Create FIRST so a save firing mid-retrieve catches the live vehicle,
// not a phantom record. We'll deleteAt the record after createVehicle
// returns a live object.
private _veh = createVehicle [_cls, _pad, [], 0, "NONE"];
if (isNull _veh) exitWith {
    private _failMsg = format ["Failed to spawn %1 (config gone?)", _cls];
    _failMsg remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    objNull
};

_veh setPosATL _pad;
clearWeaponCargoGlobal _veh;
clearMagazineCargoGlobal _veh;
clearBackpackCargoGlobal _veh;
clearItemCargoGlobal _veh;

if (_fee > 0) then {
    [_callerUID, -_fee, format ["Garage retrieve: %1", _cls]] call BO_fnc_bankAdjust;
};

_cond params [
    ["_fuelV", 1, [0]],
    ["_hp", [[],[],[]], [[]]],
    ["_aceFuel", -1, [0]],
    ["_locked", false, [false]],
    ["_ammo", [], [[]]],
    ["_att", [], [[]]],
    ["_cargo", [], [[]]],
    ["_textures", [], [[]]],
    ["_aceCargo", [], [[]]],
    ["_vectors", [[1,0,0],[0,0,1]], [[]]],
    ["_turretMags", [], [[]]]  // slot 10: full per-turret mags (newer records)
];

_veh setFuel _fuelV;

private _hpNames = _hp param [0, []];
private _hpDmg   = _hp param [2, []];
{
    private _d = _hpDmg param [_forEachIndex, 0];
    if (_d > 0) then {
        _veh setHitPointDamage [_x, _d, false];
    };
} forEach _hpNames;

if (_aceFuel >= 0 && {!isNil "ace_refuel_fnc_setFuel"}) then {
    [_veh, _aceFuel] call ace_refuel_fnc_setFuel;
};

_veh setVariable ["OT_locked", _locked, true];

if (_turretMags isNotEqualTo []) then {
    // Full multi-turret restore: strip the factory default magazines
    // from EVERY turret, then re-add exactly what was stored (mag,
    // turret path, remaining rounds) -- commander guns, FFV seats and
    // pylons all come back at their stored state.
    {
        _veh removeMagazinesTurret [_x select 0, _x select 1];
    } forEach (magazinesAllTurrets _veh);
    {
        _x params [["_mag", ""], ["_path", []], ["_cnt", 0]];
        if (_mag isNotEqualTo "") then {
            _veh addMagazineTurret [_mag, _path, _cnt];
        };
    } forEach _turretMags;
} else {
    // Legacy records (pre multi-turret): main-turret weapon ammo only.
    {
        _x params [["_w", ""], ["_n", 0]];
        if (_w isNotEqualTo "") then { _veh setAmmo [_w, _n] };
    } forEach _ammo;
};

if (_att isNotEqualTo []) then {
    _att params [["_aCls", ""], ["_aAmmo", []]];
    if (_aCls isNotEqualTo "") then {
        _veh setVariable ["OT_attachedClass", _aCls, true];
        [_veh, _aAmmo] call OT_fnc_initAttached;
    };
};

// Cargo restore -- mirrors fn_loadGame.sqf vehicle-loop cargo branch
// without the safe/password special cases (those don't apply to garage
// vehicles, which can never be the player safe).
private _cfgW = configFile >> "CfgWeapons";
private _cfgM = configFile >> "CfgMagazines";
{
    _x params [["_icls", ""], ["_num", 0]];
    if (_icls isEqualTo "") then { continue };
    if (_icls isKindOf ["Rifle", _cfgW]) exitWith {
        _veh addWeaponCargoGlobal [_icls, _num];
    };
    if (_icls isKindOf ["Pistol", _cfgW]) exitWith {
        _veh addWeaponCargoGlobal [_icls, _num];
    };
    if (_icls isKindOf ["Launcher", _cfgW]) exitWith {
        _veh addWeaponCargoGlobal [_icls, _num];
    };
    if (_icls isKindOf ["Default", _cfgM]) exitWith {
        _veh addMagazineCargoGlobal [_icls, _num];
    };
    if (_icls isKindOf "Bag_Base") exitWith {
        private _bp = _icls call BIS_fnc_basicBackpack;
        _veh addBackpackCargoGlobal [_bp, _num];
    };
    _veh addItemCargoGlobal [_icls, _num];
} forEach _cargo;

// Custom textures (faction skins / paint jobs) survive store/retrieve.
{
    _veh setObjectTextureGlobal [_forEachIndex, _x];
} forEach _textures;

if ((_aceCargo isNotEqualTo []) && {!isNil "ace_cargo_fnc_loadItem"}) then {
    {
        // Each entry is whatever ace_cargo_fnc_getCargo returned; we
        // pass it back wrapped with the vehicle.
        [_x, _veh] call ace_cargo_fnc_loadItem;
    } forEach _aceCargo;
};

if (_insured) then {
    _veh setVariable ["BO_insured", true, true];
    _veh setVariable ["BO_insurancePremium", _prem, true];
    _veh setVariable ["BO_insurancePayoutTarget", _origUID, true];
    // Payout anchors to the value AT POLICY TIME (record slot 11);
    // re-deriving from today's resolvePrice let price changes move
    // the payout after the premium was already paid.
    _veh setVariable ["BO_insuranceValueAtPolicy", ([_policyValue, _baseVal] select (_policyValue <= 0)), true];
    _veh setVariable ["OT_forceSaveUnowned", true, true];
};
if (_disp isNotEqualTo "") then {
    _veh setVariable ["BO_garageNickname", _disp, true];
};

[_veh, _callerUID] call OT_fnc_setOwner;
[_veh] call BO_fnc_installInsuranceKilledEH;

// Now safely remove the record -- the live vehicle is already spawned
// and persisted by the next save cycle through the normal vehicles
// loop, so we won't lose it if a save fires right here.
_garage deleteAt _idx;
server setVariable ["BO_garage", _garage, true];

private _auditMsg = format ["Retrieved %1 (id=%2)", _cls, _id];
[AUDIT_GARAGE, _auditMsg, [_id, _cls, _fee, _callerUID], _callerUID, _callerName] call BO_fnc_auditServer;

private _notify = format ["Vehicle retrieved ($%1 fee)", _fee];
_notify remoteExec ["OT_fnc_notifyMinor", remoteExecutedOwner, false];

_veh
