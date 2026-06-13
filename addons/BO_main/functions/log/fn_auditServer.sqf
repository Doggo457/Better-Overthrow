#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_auditServer
 *
 * Server-side audit recorder. Called directly by server-side code,
 * or via remoteExec from clients (through BO_fnc_audit). Writes an
 * event to the per-category FIFO buffer on BO_auditLog and mirrors
 * to the RPT.
 *
 * Capacity rules (set at preInit):
 *   - High-volume cats (atm):           BO_auditCapHigh entries
 *   - Medium cats     (mission):        BO_auditCapMed entries
 *   - Low cats        (save, admin,...): BO_auditCapLow entries
 *
 * When a category overflows, oldest entries are dropped (FIFO).
 *
 * Params:
 *   0: STRING - category
 *   1: STRING - description
 *   2: ANY    - details (optional payload)
 *   3: STRING - actorUID  (empty for server-initiated events)
 *   4: STRING - actorName (empty for server-initiated events)
 *
 * Returns: nothing.
 *
 * Side effects:
 *   - mutates BO_auditLog hashmap on server namespace (saved)
 *   - fires BO_fnc_log at INFO level
 */

if (!isServer) exitWith {};

// Wait until OT's `server` namespace exists. This function can be
// called very early in postInit ordering -- if it fires before OT's
// initServer.sqf has run, `server` is undefined and the getVariable
// below errors. Bail quietly; the caller's audit entry is lost but
// the call site survives.
if (isNil "server") exitWith {};

// `_details` is genuinely optional and may be omitted by callers.
// We can't give it a `nil` default in params [] -- that throws when
// the param isn't provided. Instead bind it as a free var and use
// `isNil "_details"` below to substitute an empty array when needed.
params [
    ["_category", "general", [""]],
    ["_description", "", [""]],
    "_details",
    ["_actorUID", "", [""]],
    ["_actorName", "", [""]]
];

private _detailsVal = if (isNil "_details") then { [] } else { _details };

// Capacity tier lookup. Categories not in either list fall to LOW.
private _highCats = ["atm"];
private _medCats  = ["mission", "civilian"];
private _cap = call {
    if (_category in _highCats) exitWith { missionNamespace getVariable ["BO_auditCapHigh", 1000] };
    if (_category in _medCats)  exitWith { missionNamespace getVariable ["BO_auditCapMed",  500] };
    missionNamespace getVariable ["BO_auditCapLow", 200]
};

// Pull current bucket, append, trim from the front if over capacity.
private _log = server getVariable ["BO_auditLog", createHashMap];
private _bucket = _log getOrDefault [_category, []];

private _entry = [
    date,                       // timestamp
    diag_tickTime,              // monotonic ordering aid
    _actorUID,
    _actorName,
    _description,
    _detailsVal
];
_bucket pushBack _entry;

if (count _bucket > _cap) then {
    // Trim from the head. Use deleteAt 0 only once per call so a
    // burst of writes doesn't recompute the array N times.
    _bucket deleteAt 0;
};

_log set [_category, _bucket];
server setVariable ["BO_auditLog", _log, true];

// Mirror to RPT. Subsystem in the log line matches the audit
// category so RPT tooling can filter the same way the in-game
// viewer does.
private _logLine = format [
    "%1 (actor=%2)",
    _description,
    if (_actorName isEqualTo "") then { "server" } else { _actorName }
];
["INFO", _category, _logLine] call BO_fnc_log;
