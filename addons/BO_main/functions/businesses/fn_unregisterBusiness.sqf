#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_unregisterBusiness
 *
 * Remove _business from BO_buildBusinesses. Called by the loop's
 * prune sweep when an entry has gone null/dead (e.g. building was
 * destroyed by NATO or removed by the player).
 *
 * Server-only. Idempotent (no-op if not present).
 *
 * Params:
 *   0: OBJECT - business building
 */

if (!isServer) exitWith {};

params [["_business", objNull, [objNull]]];

private _registry = server getVariable ["BO_buildBusinesses", []];
private _idx = _registry find _business;
if (_idx < 0) exitWith {};

_registry deleteAt _idx;
server setVariable ["BO_buildBusinesses", _registry, true];

private _msg = format ["Business unregistered (registry size: %1)", count _registry];
BO_LOG_INFO("business", _msg);
