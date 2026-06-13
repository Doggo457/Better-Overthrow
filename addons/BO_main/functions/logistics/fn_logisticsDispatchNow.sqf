#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsDispatchNow
 *
 * Server-auth: fire a route immediately, regardless of its schedule.
 * Used by the "Dispatch Now" button on the Routes tab. Permission
 * check identical to delete/pause (owner or General).
 *
 * Manual mode routes are designed for this -- it's their only way
 * to fire. Interval/TimeOfDay routes can also be triggered manually
 * (lastFired is updated on success, so a manual dispatch resets
 * the schedule from "now").
 *
 * Client calls:
 *   [_routeId, getPlayerUID player] remoteExec ["BO_fnc_logisticsDispatchNow", 2, false];
 */

if (!isServer) exitWith {
    _this remoteExec ["BO_fnc_logisticsDispatchNow", 2, false];
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

private _result = [_route] call BO_fnc_logisticsDispatch;

if (_result isEqualTo "ok") then {
    private _schedule = _route select 6;
    _schedule set [3, serverTime];
    _route set [6, _schedule];

    private _stats = _route select 9;
    _stats set [0, (_stats param [0, 0]) + 1];
    _stats set [1, serverTime];
    _stats set [2, ""];
    _route set [9, _stats];
} else {
    private _stats = _route select 9;
    _stats set [2, _result];
    _route set [9, _stats];
};

_routes set [_idx, _route];
server setVariable ["BO_logisticsRoutes", _routes, true];
