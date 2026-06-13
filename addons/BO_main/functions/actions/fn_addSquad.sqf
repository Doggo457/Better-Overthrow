#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_addSquad
 *
 * Server-authoritative push to the `squads` array on the OT
 * `server` namespace. Atomic on the server side: a single
 * read-modify-write under the locking guarantee that all
 * remoteExec'd-to-2 calls execute serially on the server frame
 * scheduler. Broadcasts on completion.
 *
 * The schema of a squad entry is owned by the caller (see OT's
 * fn_createSquad and fn_recruitSquad for the canonical shape).
 * This helper does not validate or dedup -- callers that need
 * idempotency should check membership before remoteExec'ing.
 *
 * Intended call site:
 *   [_squadEntry] remoteExec ["BO_fnc_addSquad", 2, false];
 *
 * Params:
 *   0: ARRAY - the squad entry to push
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [["_squadEntry", [], [[]]]];

if (_squadEntry isEqualTo []) exitWith {};

private _squads = server getVariable ["squads", []];
_squads pushBack _squadEntry;
server setVariable ["squads", _squads, true];
