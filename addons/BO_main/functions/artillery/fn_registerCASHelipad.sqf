#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerCASHelipad
 *
 * Add _helipad to the server's BO_buildCASHelipads registry and mark
 * it CAS-capable. Called either:
 *   - by the player via the "Enable CAS dispatch" ACE Main Action
 *     (one-shot per pad)
 *   - by fn_loadGame's slot-13 restore path when reloading a save
 *     where the pad had been enabled
 *
 * Idempotent on the registry; preserves an existing BO_lastCASMission
 * stamp so a save mid-cooldown survives the restore path.
 *
 * Server-only. Audits at AUDIT_ARTILLERY.
 *
 * Params:
 *   0: OBJECT - helipad
 */

SERVER_ONLY;

params [["_helipad", objNull, [objNull]], ["_callerUID", "", [""]]];
if (isNull _helipad) exitWith {};

// Generals-only gate for client-triggered calls. Server-internal
// callers (fn_loadGame slot-13 restore) pass empty _callerUID and
// skip the check -- we don't want a saved-and-enabled pad to lose
// its registration on reload because the owning player is no longer
// a General (weird policy anyway).
if (_callerUID isNotEqualTo "" && {!(_callerUID in (server getVariable ["generals", []]))}) exitWith {
    private _rmsg = format ["registerCASHelipad rejected: non-General caller uid=%1", _callerUID];
    BO_LOG_WARN("artillery", _rmsg);
};

_helipad setVariable ["BO_helipadCASEnabled", true, true];
// Preserve any restored stamp; default 0 if first-time enable.
private _existingStamp = _helipad getVariable ["BO_lastCASMission", 0];
_helipad setVariable ["BO_lastCASMission", _existingStamp, true];
_helipad setVariable ["OT_forceSaveUnowned", true, true];

private _registry = server getVariable ["BO_buildCASHelipads", []];
if !(_helipad in _registry) then {
    _registry pushBack _helipad;
    server setVariable ["BO_buildCASHelipads", _registry, true];
};

private _msg = format ["CAS helipad registered (registry size: %1)", count _registry];
BO_LOG_INFO("artillery", _msg);

[AUDIT_ARTILLERY,
    "CAS helipad enabled",
    [getPosATL _helipad, count _registry],
    "",
    ""
] call BO_fnc_auditServer;
