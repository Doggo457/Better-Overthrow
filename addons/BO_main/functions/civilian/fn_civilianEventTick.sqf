#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventTick
 *
 * One scan: enumerate eligible towns (stability >= 60, not in
 * NATOabandoned, no active event already), shuffle, take up to
 * BO_civilianEventsPerTickMax (gated by a probability roll), and
 * spawn an informant in each via BO_fnc_spawnInformant.
 *
 * Server-only.
 */

if (!isServer) exitWith {};

private _abandoned = server getVariable ["NATOabandoned", []];
private _active = server getVariable ["BO_activeCivilianEvents", []];
private _activeTowns = _active apply { _x select 1 };

private _eligible = [];
{
    private _town = _x;
    private _stab = server getVariable [format ["stability%1", _town], 0];
    if (_stab >= 60 && {!(_town in _abandoned)} && {!(_town in _activeTowns)}) then {
        _eligible pushBack _town;
    };
} forEach OT_allTowns;

if (_eligible isEqualTo []) exitWith {
    BO_LOG_DEBUG("civilian","civilianEventTick: no eligible towns this cycle");
};

private _maxPerTick = missionNamespace getVariable ["BO_civilianEventsPerTickMax", 2];
private _spawnChance = missionNamespace getVariable ["BO_civilianEventsSpawnChance", 60];
if ((random 100) > _spawnChance) exitWith {
    BO_LOG_DEBUG("civilian","civilianEventTick: probability roll skipped");
};

_eligible = _eligible call BIS_fnc_arrayShuffle;
private _toSpawn = (1 + floor (random _maxPerTick)) min (count _eligible);
for "_i" from 0 to (_toSpawn - 1) do {
    private _town = _eligible select _i;
    [_town] call BO_fnc_spawnInformant;
};

private _msg = format ["civilianEventTick: spawned %1 informant(s) from %2 eligible towns", _toSpawn, count _eligible];
BO_LOG_DEBUG("civilian", _msg);
