#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_unregisterFactory
 *
 * Remove _factory from BO_buildFactories. Used by the loop tick
 * to drop dead/null entries, and by destroy-factory flows if/when
 * we add one.
 *
 * Server-only. Audits at AUDIT_ADMIN.
 *
 * Params:
 *   0: OBJECT - factory (may be null)
 */

SERVER_ONLY;

params [["_factory", objNull, [objNull]]];

private _registry = server getVariable ["BO_buildFactories", []];
private _before = count _registry;
_registry = _registry - [_factory];
if (count _registry isEqualTo _before) exitWith {};

server setVariable ["BO_buildFactories", _registry, true];

private _msg = format ["Factory unregistered (registry size: %1)", count _registry];
BO_LOG_INFO("factory", _msg);
[AUDIT_ADMIN, "Factory unregistered", [count _registry], "", ""] call BO_fnc_auditServer;
