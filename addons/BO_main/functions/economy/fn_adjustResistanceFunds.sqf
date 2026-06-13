#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_adjustResistanceFunds
 *
 * Server-authoritative read-modify-write of the resistance treasury,
 * stored on the OT `server` namespace under the key "money". Replaces
 * the historical client-side flow where fn_giveFunds (and other
 * callers) called OT_fnc_resistanceFunds locally and clobbered any
 * concurrent donation/expense. Floors at 0 so a stale -delta can't
 * drive the treasury negative.
 *
 * Intended call site:
 *   [_delta, "Donation by Alice"] remoteExec ["BO_fnc_adjustResistanceFunds", 2, false];
 *
 * Params:
 *   0: SCALAR - signed delta (positive credits, negative debits)
 *   1: STRING - human-readable audit description (optional)
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [
    ["_delta", 0, [0]],
    ["_description", "", [""]]
];

if (_delta isEqualTo 0) exitWith {};

private _current = server getVariable ["money", 0];
private _new = (_current + _delta) max 0;
server setVariable ["money", _new, true];

private _msg = format ["adjustResistanceFunds delta=%1 new=%2 (%3)", _delta, _new, _description];
BO_LOG_INFO("econ", _msg);
