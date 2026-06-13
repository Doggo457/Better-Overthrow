#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_breakContact
 *
 * Disengage move: AWARE, clear waypoints, ONE move order to the nearest
 * road node at least 600m from contact (engine critique #1: a single
 * command, no triple-redundant chain for LAMBS to fight with).
 *
 * Params: 0: GROUP, 1: ARRAY contact pos
 * Returns: ARRAY rally pos
 */

SERVER_ONLY;
params [["_grp", grpNull, [grpNull]], ["_contact", [0,0,0], [[]]]];
if (isNull _grp) exitWith { [0,0,0] };

private _lead = leader _grp;
private _away = getPosATL _lead getPos [650, _contact getDir _lead];
private _road = [_away, 400] call BIS_fnc_nearestRoad;
private _rally = if (!isNull _road) then { getPosATL _road } else { _away };
if (surfaceIsWater _rally) then { _rally = _away };

_grp setBehaviour "AWARE";
_grp setCombatMode "GREEN";
_grp setSpeedMode "FULL";

// Clear the waypoint stack, then a single MOVE.
while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
private _wp = _grp addWaypoint [_rally, 0];
_wp setWaypointType "MOVE";
_wp setWaypointSpeed "FULL";
_wp setWaypointCompletionRadius 30;

_rally
