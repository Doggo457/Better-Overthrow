#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerBase
 *
 * Server-authoritative push to the `bases` array on the OT `server`
 * namespace. Idempotent: if the flag object in the new entry's slot 0
 * already appears in any existing entry's slot 0, the call is a no-op.
 * This protects against double-clicks, double remoteExec from races,
 * or a client retrying after a missed broadcast.
 *
 * The schema of a `bases` entry is owned by the caller; this helper
 * does not validate it past the first element (the flag object or
 * position used as the dedup key). The historical OT shape is
 *   [_flagObjectOrPos, _name, _ownerUID]
 * see fn_commitNewFOB and fn_onNameDone.
 *
 * Intended call site:
 *   [_baseEntry] remoteExec ["BO_fnc_registerBase", 2, false];
 *
 * Params:
 *   0: ARRAY - the full base entry to push, slot 0 = flag/pos key
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [["_baseEntry", [], [[]]]];

if (_baseEntry isEqualTo []) exitWith {};

private _key = _baseEntry select 0;
private _bases = server getVariable ["bases", []];

// Idempotency check. Compare slot 0 of each existing entry against
// the new entry's slot 0. isEqualTo handles both object refs and
// position arrays correctly.
private _dupIdx = _bases findIf { (_x select 0) isEqualTo _key };
if (_dupIdx >= 0) exitWith {
    private _msg = format ["registerBase: skip duplicate key=%1", _key];
    BO_LOG_INFO("admin", _msg);
};

_bases pushBack _baseEntry;
server setVariable ["bases", _bases, true];

// BO HAL hook: every registered FOB enters HAL's watch registry.
if (!isNil "BO_HAL_fnc_fobTouch") then {
    [_baseEntry] call BO_HAL_fnc_fobTouch;
};

[AUDIT_ADMIN,
 format ["registerBase key=%1 entry=%2", _key, _baseEntry],
 _baseEntry,
 "",
 ""
] call BO_fnc_auditServer;
