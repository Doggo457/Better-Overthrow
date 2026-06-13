#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_addRecruit
 *
 * Server-authoritative push to the `recruits` array on the OT
 * `server` namespace. Companion to BO_fnc_addSquad. Atomic single
 * read-modify-write, broadcasts on completion.
 *
 * The schema of a recruit entry is owned by the caller (see OT's
 * fn_initRecruit). No validation or dedup -- callers handle
 * idempotency.
 *
 * Intended call site:
 *   [_recruitEntry] remoteExec ["BO_fnc_addRecruit", 2, false];
 *
 * Params:
 *   0: ARRAY - the recruit entry to push
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [["_recruitEntry", [], [[]]]];

if (_recruitEntry isEqualTo []) exitWith {};

private _recruits = server getVariable ["recruits", []];
_recruits pushBack _recruitEntry;
server setVariable ["recruits", _recruits, true];
