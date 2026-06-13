#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerBusiness
 *
 * Add _business to the server's BO_buildBusinesses registry, the
 * source of truth iterated by BO_fnc_businessLoop's PFH tick.
 *
 * Idempotent: silently skips if _business is already in the registry
 * or is null/dead. Defaults BO_businessEnabled to true if it's not
 * been set yet so a freshly loaded business ticks immediately.
 *
 * Server-only. Audits at AUDIT_ADMIN.
 *
 * Params:
 *   0: OBJECT - business building
 */

if (!isServer) exitWith {};

params [["_business", objNull, [objNull]]];
if (isNull _business) exitWith {};
if (!alive _business) exitWith {};

private _registry = server getVariable ["BO_buildBusinesses", []];
if (_business in _registry) exitWith {
    private _msg = format ["registerBusiness: %1 already registered", _business];
    BO_LOG_DEBUG("business", _msg);
};

_registry pushBack _business;
server setVariable ["BO_buildBusinesses", _registry, true];

if (isNil { _business getVariable "BO_businessEnabled" }) then {
    _business setVariable ["BO_businessEnabled", true, true];
};

private _type = _business getVariable ["BO_businessType", "?"];
private _msg = format ["Business registered: %1 (registry size: %2)", _type, count _registry];
BO_LOG_INFO("business", _msg);
[AUDIT_ADMIN, "Business registered", [_type, getPosATL _business, count _registry], "", ""] call BO_fnc_auditServer;
