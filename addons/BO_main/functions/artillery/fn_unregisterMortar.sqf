#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_unregisterMortar
 *
 * Counterpart to BO_fnc_registerMortar. Called by the garbage
 * collector / save-load pruning when a mortar is destroyed or
 * vanishes. Mirrors fn_unregisterFactory.
 *
 * Server-only.
 *
 * Params:
 *   0: OBJECT - mortar (may be null)
 */

SERVER_ONLY;

params [["_mortar", objNull, [objNull]]];

private _registry = server getVariable ["BO_buildMortars", []];
private _before = count _registry;
_registry = _registry - [_mortar];
if (count _registry isEqualTo _before) exitWith {};

server setVariable ["BO_buildMortars", _registry, true];

private _msg = format ["unregisterMortar: removed %1 (registry size: %2)", _mortar, count _registry];
BO_LOG_INFO("artillery", _msg);
