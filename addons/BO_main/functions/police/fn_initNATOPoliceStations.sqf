#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initNATOPoliceStations
 *
 * Server-only postInit. For every NATO-controlled town not already in
 * BO_natoPoliceStations, calls BO_fnc_spawnNATOPoliceStation to do
 * the persistent setup pass (flag + addAction + map marker + OT
 * spawner registration). The actual SWAT garrison + crates + vehicle
 * spawn via BO_fnc_spawnPoliceStationGarrison when a player enters
 * the OT virtualization spawn distance of the station.
 *
 * Idempotent: safe to call on a reload.
 */

if (!isServer) exitWith {};

if (isNil "OT_allTowns") exitWith {
    BO_LOG_WARN("police", "initNATOPoliceStations: OT_allTowns nil, deferring");
};

// LOAD-path gate: postLoadHydratePolice has already walked the persistent
// registry and rebound netIds / markers / flag / spawner. Re-running
// per-town election here would duplicate-spawn against adopted buildings.
// NEW path is unaffected (StartupType != "LOAD").
private _startup = server getVariable ["StartupType", ""];
if (_startup isEqualTo "LOAD" && {(server getVariable ["BO_natoPoliceStations", []]) isNotEqualTo []}) exitWith {
    BO_LOG_INFO("police", "initNATOPoliceStations: load path, deferred to hydrate");
};

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_allTowns select { !(_x in _abandoned) };

private _stations = server getVariable ["BO_natoPoliceStations", []];
private _spawned = 0;
{
    private _town = _x;
    private _hasEntry = (_stations findIf { (_x select 0) isEqualTo _town }) >= 0;
    if (!_hasEntry) then {
        if ([_town] call BO_fnc_spawnNATOPoliceStation) then {
            _spawned = _spawned + 1;
        };
    };
} forEach _natoTowns;

private _msg = format ["initNATOPoliceStations: %1 newly registered, %2 total", _spawned, count (server getVariable ["BO_natoPoliceStations", []])];
BO_LOG_INFO("police", _msg);
