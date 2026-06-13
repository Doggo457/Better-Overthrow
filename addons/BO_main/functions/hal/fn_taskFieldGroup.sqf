#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_taskFieldGroup
 *
 * Hot-branch first responder: before paying to spawn a package, task
 * the nearest adopted field group (BO_HAL_fieldPool) at the sighting.
 * Garrison-role groups are never pulled -- they defend their base
 * (the user-facing rule: garrisons generally stay home).
 *
 * Zero budget cost: these are existing world units. Registered as a
 * kind "field" op so evaluateOp drives transit/active and RELEASES
 * (never deletes) them on completion.
 *
 * Params: 0: ARRAY target pos
 * Returns: BOOL tasked
 */

SERVER_ONLY;
params [["_tgt", [], [[]]]];
if (_tgt isEqualTo []) exitWith { false };
if (count BO_HAL_activeOps >= BO_HAL_maxConcurrentOps) exitWith { false };

private _pool = missionNamespace getVariable ["BO_HAL_fieldPool", []];
if (_pool isEqualTo []) exitWith { false };

private _best = grpNull;
private _bestD = 3500; // beyond this a fresh package responds faster
{
    private _grp = _x;
    if (!isNull _grp
        && {isNil { _grp getVariable "BO_HAL_op" }}
        && {(_grp getVariable ["BO_HAL_role", "field"]) isNotEqualTo "garrison"}
        && {({ alive _x } count units _grp) >= 3}) then {
        private _d = (leader _grp) distance2D _tgt;
        if (_d < _bestD) then { _bestD = _d; _best = _grp };
    };
} forEach _pool;

if (isNull _best) exitWith { false };

private _opId = (server getVariable ["BO_HAL_opCounter", 0]) + 1;
server setVariable ["BO_HAL_opCounter", _opId];

_best setVariable ["BO_HAL_op", _opId, false];
_best setVariable ["initialStrength", ({ alive _x } count units _best) max 1, false];

while { count waypoints _best > 0 } do { deleteWaypoint [_best, 0] };
private _wp = _best addWaypoint [_tgt getPos [60, random 360], 0];
_wp setWaypointType "MOVE";
_wp setWaypointSpeed "FULL";
_wp setWaypointCompletionRadius 25;
_best setBehaviour "AWARE";
_best setCombatMode "YELLOW";
_best setSpeedMode "FULL";

private _anchor = _best getVariable ["BO_HAL_anchor", getPosATL (leader _best)];
BO_HAL_activeOps pushBack [
    _opId, "FIELD_RESPONSE", _best, objNull, grpNull, +_tgt, +_anchor,
    serverTime, "transit", { alive _x } count units _best, 0, 0, "field", serverTime, []
];

["field_task", [_opId, groupId _best, round _bestD]] call BO_HAL_fnc_aar;
private _msg = format ["HAL field-task op=%1 grp=%2 dist=%3m", _opId, groupId _best, round _bestD];
BO_LOG_INFO("hal", _msg);
true
