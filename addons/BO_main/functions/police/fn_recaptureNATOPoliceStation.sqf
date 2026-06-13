#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_recaptureNATOPoliceStation
 *
 * Server-only. Called from BO_fnc_NATOCounterTown's success branch
 * when NATO retakes a town. Tear down the existing station, then
 * defer a fresh BO_fnc_spawnNATOPoliceStation call so NATO control
 * gets the same flag + marker + virtualization treatment as the
 * initial postInit setup.
 *
 * Params:
 *   0: STRING - town name
 */

if (!isServer) exitWith {};

// RPT-found fix: OT's counter-attack callback chain can invoke this
// from engine GLOBAL space (trigger statements), where params/private
// throw "Local variable in global space". Re-enter ourselves on the
// scheduler, where locals are legal.
if (!canSuspend) exitWith { _this spawn BO_fnc_recaptureNATOPoliceStation };

params [["_town", "", [""]]];
if (_town isEqualTo "") exitWith {};

private _stations = server getVariable ["BO_natoPoliceStations", []];
private _idx = _stations findIf { (_x select 0) isEqualTo _town };
if (_idx < 0) exitWith {};

private _entry = _stations select _idx;
_entry params [
    ["_t", "", [""]],
    ["_pos", [0,0,0], [[]]],
    ["_captured", false, [false]],
    ["_buildNetId", "", [""]],
    ["_crateNetIds", [], [[]]],
    ["_vehNetId", "", [""]],
    ["", grpNull, [grpNull]],
    ["_markerId", "", [""]],
    ["_adopted", false, [false]],
    ["_flagNetId", "", [""]],
    ["_spawnerId", "", [""]],
    ["", [], [[]]]
];

private _building = objectFromNetId _buildNetId;
private _crates   = _crateNetIds apply { objectFromNetId _x };
private _vehicle  = objectFromNetId _vehNetId;
private _flag     = objectFromNetId _flagNetId;

if (_markerId isNotEqualTo "") then { deleteMarker _markerId };
if (!isNull _flag) then { deleteVehicle _flag };

// Adopted (map-baked) buildings are NOT deleted -- only the sentinel
// owner needs clearing so the fresh spawn can re-acquire it.
if (!isNull _building) then {
    if (_adopted) then {
        [_building, ""] call OT_fnc_setOwner;
        _building setVariable ["BO_natoStationOwner", nil, true];
    } else {
        deleteVehicle _building;
    };
};

// Despawn the live transient garrison + crates + vehicle by clearing
// the OT spawner's tracked list and deregistering the spawner so it
// won't fire again.
if (_spawnerId isNotEqualTo "") then {
    private _groups = spawner getVariable [_spawnerId, []];
    {
        if (_x isEqualType grpNull) then {
            { deleteVehicle _x } forEach (units _x);
            deleteGroup _x;
        };
        if (_x isEqualType objNull && {!isNull _x}) then { deleteVehicle _x };
    } forEach _groups;
    spawner setVariable [_spawnerId, [], false];
    // Bare string, not [_spawnerId] -- deregisterSpawner matches _x#0
    // isEqualTo _this against the "spawnN" string in OT_allSpawners.
    _spawnerId call OT_fnc_deregisterSpawner;
};

// Belt-and-braces: anything still alive that the spawner missed.
{ if (!isNull _x) then { deleteVehicle _x } } forEach _crates;
if (!isNull _vehicle) then { deleteVehicle _vehicle };

// Drop entry + any in-progress capture state.
_stations deleteAt _idx;
server setVariable ["BO_natoPoliceStations", _stations, true];

{
    missionNamespace setVariable [format [_x, _town], nil, true];
} forEach [
    "BO_polcap_active_%1", "BO_polcap_circleId_%1", "BO_polcap_start_%1",
    "BO_polcap_callerUID_%1", "BO_polcap_outSince_%1",
    "BO_polcap_reinforce_%1", "BO_polcap_pfh_%1"
];

// Defer the respawn a couple seconds so any active NATO-counter
// cleanup finishes its own teardown first.
[{
    params ["_town"];
    [_town] call BO_fnc_spawnNATOPoliceStation;
}, [_town], 3] call CBA_fnc_waitAndExecute;

[AUDIT_ADMIN, format ["NATO Police Station retaken at %1", _town], [_town], "", ""] call BO_fnc_auditServer;
private _msg = format ["NATO Police Station retaken at %1 -- respawn queued", _town];
BO_LOG_INFO("police", _msg);
