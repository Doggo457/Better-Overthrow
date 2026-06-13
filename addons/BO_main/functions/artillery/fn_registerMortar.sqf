#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerMortar
 *
 * Add _mortar to the server's BO_buildMortars registry. Mirrors
 * BO_fnc_registerFactory's shape so cleanup / save-iteration /
 * pruning patterns stay identical across the two systems.
 *
 * Idempotent: silently skips if _mortar is already in the registry
 * or is null/dead.
 *
 * Server-only. Audits at AUDIT_ARTILLERY.
 *
 * Params:
 *   0: OBJECT - mortar
 */

SERVER_ONLY;

params [["_mortar", objNull, [objNull]]];
if (isNull _mortar) exitWith {};
if (!alive _mortar) exitWith {};

private _registry = server getVariable ["BO_buildMortars", []];
if (_mortar in _registry) exitWith {
    private _msg = format ["registerMortar: %1 already registered", _mortar];
    BO_LOG_DEBUG("artillery", _msg);
};

_registry pushBack _mortar;
server setVariable ["BO_buildMortars", _registry, true];

private _msg = format ["Mortar registered (registry size: %1)", count _registry];
BO_LOG_INFO("artillery", _msg);

[AUDIT_ARTILLERY,
    "Mortar registered",
    [getPosATL _mortar, count _registry],
    "",
    ""
] call BO_fnc_auditServer;
