#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_adjustTownCounter
 *
 * Server-authoritative read-modify-write of any of the per-town
 * scalar counters OT keeps on the `server` namespace. Generic
 * because the police, CRIM presence, and employment counters all
 * share the same key-format pattern -- a single format string with
 * `%1` substituted for the town name (e.g. "police%1", "CRIM%1",
 * "%1employ"). The full variable name is `format [_keyFormat, _town]`.
 * Result clamped at >= 0 so a stale -delta can't drive the counter
 * negative. Broadcasts the new value.
 *
 * Intended call site:
 *   ["police%1", _town, +1] remoteExec ["BO_fnc_adjustTownCounter", 2, false];
 *   ["%1employ", _town, -1] remoteExec ["BO_fnc_adjustTownCounter", 2, false];
 *
 * Params:
 *   0: STRING - key format string (must contain a single %1)
 *   1: STRING - town name (substituted into the format)
 *   2: SCALAR - signed delta
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [
    ["_keyFormat", "%1police", [""]],
    ["_town", "", [""]],
    ["_delta", 0, [0]]
];

if (_town isEqualTo "") exitWith {};
if (_delta isEqualTo 0) exitWith {};

private _key = format [_keyFormat, _town];
private _current = server getVariable [_key, 0];
private _new = (_current + _delta) max 0;
server setVariable [_key, _new, true];
