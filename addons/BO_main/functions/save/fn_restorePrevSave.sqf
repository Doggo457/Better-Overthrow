#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_restorePrevSave
 *
 * Promote the .prev backup slot written by BO_fnc_backupSave back into
 * the live OT_saveName slot, then trigger a load. Use this when the
 * current save is corrupt or the player wants to roll back the most
 * recent save.
 *
 * Server-authoritative. From a client, call as:
 *   [] remoteExec ["BO_fnc_restorePrevSave", 2, false];
 *
 * Returns: BOOL - true if rollback applied, false if no .prev slot.
 */
SERVER_ONLY_RET(false);

// Server-side privilege check: a save rollback is destructive, so the
// remoteExec path only honors the server (0), the hosting player (2),
// or a logged-in admin client. Generals carry OT_adminMode but do NOT
// qualify for this.
private _ro = remoteExecutedOwner;
if (_ro > 2 && {(admin _ro) isNotEqualTo 2}) exitWith {
    private _wmsg = format ["restorePrevSave: rejected non-admin caller (owner %1)", _ro];
    BO_LOG_WARN("save", _wmsg);
    false
};

if (isNil "OT_saveName") exitWith {
    BO_LOG_WARN("save","restorePrevSave called before OT_saveName initialized");
    false
};

private _prevKey = format ["%1.prev", OT_saveName];

private _prev = if (isMissionProfileNamespaceLoaded) then {
    missionProfileNamespace getVariable [_prevKey, ""]
} else {
    profileNamespace getVariable [_prevKey, ""]
};

if (_prev isEqualType "" && { _prev isEqualTo "" }) exitWith {
    BO_LOG_WARN("save","restorePrevSave: no .prev slot to restore");
    "No previous save slot to restore" remoteExec ["OT_fnc_notifyBad", 0, false];
    false
};

// Promote .prev into the live slot and persist immediately so a crash
// before the next save doesn't lose the rollback.
if (isMissionProfileNamespaceLoaded) then {
    missionProfileNamespace setVariable [OT_saveName, _prev];
    saveMissionProfileNamespace;
} else {
    profileNamespace setVariable [OT_saveName, _prev];
    saveProfileNamespace;
};

[AUDIT_SAVE, "Restored previous save slot (.prev -> main)", [_prevKey], "", ""] call BO_fnc_auditServer;
BO_LOG_INFO("save","Previous save slot restored; triggering load");

"Previous save restored -- loading..." remoteExec ["OT_fnc_notifyAndLog", 0, false];

// Fire the load on the server.
[] spawn OT_fnc_loadGame;

true
