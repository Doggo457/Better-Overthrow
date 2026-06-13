#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerWarehouse
 *
 * Server-authoritative push to the warehouse-ownership array. OT
 * stores this on the `warehouse` namespace object under the key
 * "owned" (confirmed via fn_buyBuilding and fn_build). Idempotent:
 * skips if the building is already in the list. Broadcasts the
 * updated array on success.
 *
 * Intended call site:
 *   [_building] remoteExec ["BO_fnc_registerWarehouse", 2, false];
 *
 * Params:
 *   0: OBJECT - the warehouse building object to register
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [["_building", objNull, [objNull]]];

if (isNull _building) exitWith {};

private _owned = warehouse getVariable ["owned", []];
if (_building in _owned) exitWith {
    private _msg = format ["registerWarehouse: skip duplicate %1", _building];
    BO_LOG_INFO("admin", _msg);
};

_owned pushBack _building;
warehouse setVariable ["owned", _owned, true];

[AUDIT_ADMIN,
 format ["registerWarehouse: %1", _building],
 [_building],
 "",
 ""
] call BO_fnc_auditServer;
