#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsPauseRoute
 *
 * Server-auth: toggle the paused flag on a route. Active deliveries
 * already dispatched continue to their ETA regardless.
 *
 * Client calls:
 *   [_routeId, getPlayerUID player] remoteExec ["BO_fnc_logisticsPauseRoute", 2, false];
 */

if (!isServer) exitWith {
    _this remoteExec ["BO_fnc_logisticsPauseRoute", 2, false];
};

params [["_routeId", "", [""]], ["_callerUID", "", [""]]];
if (_routeId isEqualTo "") exitWith {};

private _routes = server getVariable ["BO_logisticsRoutes", []];
private _idx = _routes findIf { (_x select 0) isEqualTo _routeId };
if (_idx < 0) exitWith {};

private _route = _routes select _idx;
private _ownerUID = _route select 1;
private _generals = server getVariable ["generals", []];
if !((_callerUID isEqualTo _ownerUID) || (_callerUID in _generals)) exitWith {};

private _wasPaused = _route select 8;
_route set [8, !_wasPaused];
_routes set [_idx, _route];
server setVariable ["BO_logisticsRoutes", _routes, true];

private _m = format ["Route %1: %2", _routeId, if (_wasPaused) then { "resumed" } else { "paused" }];
[AUDIT_MISSION, _m, [_routeId], _callerUID, ""] call BO_fnc_auditServer;
