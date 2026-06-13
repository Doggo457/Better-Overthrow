#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsDeleteRoute
 *
 * Server-auth: remove a route and roll back any in-flight deliveries
 * belonging to it (payload returned to source if alive, else lost
 * with an audit entry).
 *
 * Permissions: caller UID must match route owner OR caller must be
 * a General (server-side check via OT_fnc_playerIsGeneral lookup
 * against the generals list).
 *
 * Client calls:
 *   [_routeId, getPlayerUID player] remoteExec ["BO_fnc_logisticsDeleteRoute", 2, false];
 */

if (!isServer) exitWith {
    _this remoteExec ["BO_fnc_logisticsDeleteRoute", 2, false];
};

params [["_routeId", "", [""]], ["_callerUID", "", [""]]];
if (_routeId isEqualTo "") exitWith {};

private _routes = server getVariable ["BO_logisticsRoutes", []];
private _idx = _routes findIf { (_x select 0) isEqualTo _routeId };
if (_idx < 0) exitWith {
    BO_LOG_WARN("logistics", "deleteRoute: route not found");
};

private _route = _routes select _idx;
private _ownerUID = _route select 1;

private _generals = server getVariable ["generals", []];
private _allowed = (_callerUID isEqualTo _ownerUID) || (_callerUID in _generals);
if (!_allowed) exitWith {
    BO_LOG_WARN("logistics", "deleteRoute: caller not authorized");
};

// Roll back any in-flight deliveries for this route.
private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];
private _remaining = [];
{
    if ((_x select 1) isEqualTo _routeId) then {
        // Use the standard arrive-with-missing-destination rollback path.
        // We force a "destination gone" by zeroing the dst before calling.
        // Simpler: just call BO_fnc_logisticsArrive after blanking _dstId
        // -- the arrive function handles the rollback to source.
        private _spoofed = +_x;
        _spoofed set [6, ""]; // blank dstId so arrive can't find it
        [_spoofed] call BO_fnc_logisticsArrive;
    } else {
        _remaining pushBack _x;
    };
} forEach _deliveries;
server setVariable ["BO_logisticsActiveDeliveries", _remaining, true];

_routes deleteAt _idx;
server setVariable ["BO_logisticsRoutes", _routes, true];

private _m = format ["Route deleted: %1", _routeId];
[AUDIT_MISSION, _m, [_routeId], _callerUID, ""] call BO_fnc_auditServer;
