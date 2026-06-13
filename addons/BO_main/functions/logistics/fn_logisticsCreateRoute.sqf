#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsCreateRoute
 *
 * Server-auth: append a new route to BO_logisticsRoutes.
 *
 * Client calls via:
 *   [_payload] remoteExec ["BO_fnc_logisticsCreateRoute", 2, false];
 * where _payload is a partial route record (the route id is
 * generated server-side so clients can't collide on it).
 *
 * Local-host pattern: branch on arg count, not !isServer (the host
 * is both server AND client, per BO_fnc memory). Actual server-side
 * logic only runs once.
 *
 * Validation:
 *   - srcId / dstId must resolve to live tagged containers
 *   - srcId != dstId
 *   - schedule mode in {MANUAL, INTERVAL, TIMEOFDAY}
 *   - fee >= 0
 *
 * Params (in _payload):
 *   0: STRING - ownerUID (creator)
 *   1: STRING - srcContainerId
 *   2: STRING - dstContainerId
 *   3: ARRAY  - items filter ([] for all, else classnames)
 *   4: NUMBER - qtyPerTrip (-1 = all matching)
 *   5: ARRAY  - schedule [_mode, _intervalMin, _timeOfDay]
 *   6: NUMBER - fee per trip
 *   7: BOOL   - skipIfEmpty
 */

if (!isServer) exitWith {
    _this remoteExec ["BO_fnc_logisticsCreateRoute", 2, false];
};

params [["_payload", [], [[]]]];

_payload params [
    ["_ownerUID",    "", [""]],
    ["_srcId",       "", [""]],
    ["_dstId",       "", [""]],
    ["_items",       [], [[]]],
    ["_qtyPerTrip",  -1, [0]],
    ["_schedule",    ["MANUAL", 60, [0, 0]], [[]]],
    ["_fee",         0,  [0]],
    ["_skipIfEmpty", true, [true]]
];

if (_ownerUID isEqualTo "" || _srcId isEqualTo "" || _dstId isEqualTo "" || _srcId isEqualTo _dstId) exitWith {
    BO_LOG_WARN("logistics", "createRoute rejected: bad ids");
};

private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
if (isNull _src || isNull _dst) exitWith {
    BO_LOG_WARN("logistics", "createRoute rejected: container not resolvable");
};

_schedule params [["_mode", "MANUAL"], ["_intervalMin", 60], ["_timeOfDay", [0, 0]]];
if !(_mode in ["MANUAL", "INTERVAL", "TIMEOFDAY"]) exitWith {
    BO_LOG_WARN("logistics", "createRoute rejected: bad schedule mode");
};

if (_fee < 0) then { _fee = 0 };

private _routeId = format ["r_%1_%2", round diag_tickTime, round (random 999999)];
private _now = serverTime;

// Schedule record: [_mode, _intervalMin, _timeOfDay, _lastFired]
private _schedRecord = [_mode, _intervalMin, _timeOfDay, _now];

// Stats: [_totalTrips, _lastSuccessTime, _lastFailureReason]
private _stats = [0, 0, ""];

private _route = [
    _routeId, _ownerUID, _srcId, _dstId,
    _items, _qtyPerTrip,
    _schedRecord, _fee,
    false,            // paused
    _stats,
    _skipIfEmpty
];

private _routes = server getVariable ["BO_logisticsRoutes", []];
_routes pushBack _route;
server setVariable ["BO_logisticsRoutes", _routes, true];

private _label = format ["Route created: src=%1 dst=%2 mode=%3 fee=$%4", _srcId, _dstId, _mode, _fee];
[AUDIT_MISSION, _label, [_routeId, _srcId, _dstId, _mode, _fee], _ownerUID, ""] call BO_fnc_auditServer;
