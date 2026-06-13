#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerFactory
 *
 * Add _factory to the server's BO_buildFactories registry, the
 * source of truth iterated by BO_fnc_factoryLoop's PFH tick.
 *
 * Idempotent: silently skips if _factory is already in the registry
 * or is null/dead. Defaults BO_factoryEnabled to true if it's not
 * been set yet so a freshly loaded factory ticks immediately.
 *
 * Server-only. Audits at AUDIT_ADMIN.
 *
 * Params:
 *   0: OBJECT - factory
 */

SERVER_ONLY;

params [["_factory", objNull, [objNull]]];
if (isNull _factory) exitWith {};
if (!alive _factory) exitWith {};

private _registry = server getVariable ["BO_buildFactories", []];
if (_factory in _registry) exitWith {
    private _msg = format ["registerFactory: %1 already registered", _factory];
    BO_LOG_DEBUG("factory", _msg);
};

_registry pushBack _factory;
server setVariable ["BO_buildFactories", _registry, true];

if (isNil { _factory getVariable "BO_factoryEnabled" }) then {
    _factory setVariable ["BO_factoryEnabled", true, true];
};

private _msg = format ["Factory registered (registry size: %1)", count _registry];
BO_LOG_INFO("factory", _msg);
[AUDIT_ADMIN, "Factory registered", [getPosATL _factory, count _registry], "", ""] call BO_fnc_auditServer;
