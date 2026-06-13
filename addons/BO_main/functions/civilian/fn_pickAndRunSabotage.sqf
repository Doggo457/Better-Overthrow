#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_pickAndRunSabotage
 *
 * Pick the highest-stability non-abandoned town (proxy for "most
 * pro-resistance region"), find the nearest live NATO objective /
 * airport base to it, roll one of three sabotage effects, dispatch.
 *
 * History trim: BO_sabotageHistory is kept at 30 entries max,
 * FIFO. The 24h intel reveal walks this list.
 *
 * Server-only.
 */

if (!isServer) exitWith {};

private _abandoned = server getVariable ["NATOabandoned", []];

private _candidates = OT_allTowns select { !(_x in _abandoned) };
if (_candidates isEqualTo []) exitWith {
    BO_LOG_DEBUG("civilian","sabotage: no candidate towns");
};

// Sort towns by stability DESCEND; use negative value with ASCEND
// because BIS_fnc_sortBy doesn't take a direction argument that
// some builds honour. The first element after sort is the highest.
private _sorted = [_candidates, [], { -(server getVariable [format ["stability%1", _x], 0]) }, "ASCEND"] call BIS_fnc_sortBy;
private _bestTown = _sorted select 0;
private _bestStab = server getVariable [format ["stability%1", _bestTown], 0];
if (_bestStab < 60) exitWith {
    private _msg = format ["sabotage: no region above 60 stability (best=%1 @ %2)", _bestStab, _bestTown];
    BO_LOG_DEBUG("civilian", _msg);
};

private _townPos = server getVariable [_bestTown, [0,0,0]];

// Nearest non-abandoned NATO objective/airport base.
private _allBases = [];
if (!isNil "OT_objectiveData") then { _allBases append OT_objectiveData };
if (!isNil "OT_airportData")   then { _allBases append OT_airportData };
private _bases = _allBases select { !((_x select 1) in _abandoned) };
if (_bases isEqualTo []) exitWith {
    BO_LOG_DEBUG("civilian","sabotage: no live NATO bases");
};

private _baseSorted = [_bases, [], { (_x select 0) distance2D _townPos }, "ASCEND"] call BIS_fnc_sortBy;
private _targetBase = _baseSorted select 0;
_targetBase params ["_basePos", "_baseName"];

private _effects = ["vehicle_fire", "supply_theft", "garrison_desertion"];
private _effect = selectRandom _effects;

[_baseName, _basePos, _effect] call BO_fnc_applySabotageEffect;

private _flavor = switch (_effect) do {
    case "vehicle_fire":      { format ["rumors of a NATO vehicle fire near %1", _bestTown] };
    case "supply_theft":      { format ["rumors that NATO supplies were stolen near %1", _bestTown] };
    case "garrison_desertion":{ format ["rumors of NATO desertions near %1", _bestTown] };
    default                   { format ["rumors of NATO trouble near %1", _bestTown] };
};
_flavor remoteExec ["OT_fnc_notifyMinor", 0, false];

private _history = server getVariable ["BO_sabotageHistory", []];
_history pushBack [date, _baseName, _effect, [_basePos, _bestTown]];
if (count _history > 30) then { _history deleteAt 0 };
server setVariable ["BO_sabotageHistory", _history, true];

[_baseName, _effect] remoteExec ["BO_fnc_sabotageMarker", 0, true];

private _auditMsg = format ["Nighttime sabotage at %1 (%2)", _baseName, _effect];
[AUDIT_CIVILIAN, _auditMsg, [_baseName, _bestTown, _effect, _basePos], "", ""] call BO_fnc_auditServer;
