#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryProduceOne
 *
 * Spawn the output of a completed production cycle for _factory.
 * Per-object: reads _currentCls + _numtoproduce, dispatches by
 * isKindOf -- vehicles spawn at the per-factory vehicle spawn
 * point computed by BO_fnc_factoryVehicleSpawnPos; everything else
 * goes into the factory's BO_outputContainer (auto-ensured if it's
 * gone missing).
 *
 * Returns true on success, false if there was no room to spawn a
 * vehicle output (caller pins timespent to timetoproduce so the
 * loop doesn't infinite-retry).
 *
 * Server-only.
 *
 * Params:
 *   0: OBJECT - factory
 *   1: STRING - classname being produced
 *   2: SCALAR - quantity to produce
 *
 * Returns: BOOL - true on success.
 */

SERVER_ONLY_RET(false);

params [
    ["_factory", objNull, [objNull]],
    ["_currentCls", "", [""]],
    ["_numtoproduce", 1, [0]]
];
if (isNull _factory) exitWith { false };
if (_currentCls isEqualTo "") exitWith { false };

private _isVehicle = (!(_currentCls isKindOf "Bag_Base")) && (_currentCls isKindOf "AllVehicles");

if (_isVehicle) exitWith {
    ([_factory] call BO_fnc_factoryVehicleSpawnPos) params ["_spawnPos", "_spawnDir"];
    private _p = _spawnPos findEmptyPosition [5, 100, _currentCls];
    if (_p isEqualTo []) exitWith {
        private _name = _currentCls call OT_fnc_vehicleGetName;
        format ["Factory has no room to produce %1, please clear the road", _name] remoteExec ["OT_fnc_notifyMinor", 0, false];
        false
    };

    private _veh = _currentCls createVehicle _p;
    _veh setVariable ["OT_forceSaveUnowned", true, true];
    clearWeaponCargoGlobal _veh;
    clearMagazineCargoGlobal _veh;
    clearBackpackCargoGlobal _veh;
    clearItemCargoGlobal _veh;
    _veh setDir _spawnDir;

    private _name = _currentCls call OT_fnc_vehicleGetName;
    format ["Factory has produced %1 x %2", _numtoproduce, _name] remoteExec ["OT_fnc_notifyMinor", 0, false];

    private _logMsg = format ["produceOne vehicle %1 x %2 at %3", _numtoproduce, _currentCls, _p];
    BO_LOG_INFO("factory", _logMsg);
    [AUDIT_ADMIN, "Factory produced vehicle", [_currentCls, _numtoproduce, getPosATL _factory], "", ""] call BO_fnc_auditServer;
    true
};

// Non-vehicle output -- backpack/weapon/mag/item -> BO_outputContainer.
private _crate = [_factory] call BO_fnc_factoryEnsureOutputContainer;
if (isNull _crate) exitWith {
    format ["Factory has no room to place output container, please clear marker area"] remoteExec ["OT_fnc_notifyMinor", 0, false];
    false
};

[_crate, _currentCls, _numtoproduce] call {
    params ["_crate", "_currentCls", "_numtoproduce"];
    if (_currentCls isKindOf "Bag_Base") exitWith {
        _currentCls = _currentCls call BIS_fnc_basicBackpack;
        _crate addBackpackCargoGlobal [_currentCls, _numtoproduce];
    };
    if (_currentCls isKindOf ["Rifle", configFile >> "CfgWeapons"]) exitWith {
        _crate addWeaponCargoGlobal [_currentCls, _numtoproduce];
    };
    if (_currentCls isKindOf ["Launcher", configFile >> "CfgWeapons"]) exitWith {
        _crate addWeaponCargoGlobal [_currentCls, _numtoproduce];
    };
    if (_currentCls isKindOf ["Pistol", configFile >> "CfgWeapons"]) exitWith {
        _crate addWeaponCargoGlobal [_currentCls, _numtoproduce];
    };
    if (_currentCls isKindOf ["Default", configFile >> "CfgMagazines"]) exitWith {
        _crate addMagazineCargoGlobal [_currentCls, _numtoproduce];
    };
    _crate addItemCargoGlobal [_currentCls, _numtoproduce];
};

private _logMsg = format ["produceOne item %1 x %2", _numtoproduce, _currentCls];
BO_LOG_INFO("factory", _logMsg);
[AUDIT_ADMIN, "Factory produced item", [_currentCls, _numtoproduce, getPosATL _factory], "", ""] call BO_fnc_auditServer;
true
