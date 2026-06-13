#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_backupSave
 *
 * Copy the current saved payload to <OT_saveName>.prev so a corrupt
 * write doesn't wipe the previous good state. Called from saveGame
 * BEFORE the new payload is committed.
 *
 * No-op when there's nothing yet at the current slot (first save).
 */

SERVER_ONLY;

if (isNil "OT_saveName") exitWith {
    BO_LOG_WARN("save","backupSave called before OT_saveName initialized");
};

private _prevKey = format ["%1.prev", OT_saveName];

private _existing = if (isMissionProfileNamespaceLoaded) then {
    missionProfileNamespace getVariable [OT_saveName, ""]
} else {
    profileNamespace getVariable [OT_saveName, ""]
};

if (_existing isEqualType "" && { _existing isEqualTo "" }) exitWith {
    BO_LOG_INFO("save","backupSave: no prior save to back up");
};

if (isMissionProfileNamespaceLoaded) then {
    missionProfileNamespace setVariable [_prevKey, _existing];
    saveMissionProfileNamespace;
} else {
    profileNamespace setVariable [_prevKey, _existing];
    saveProfileNamespace;
};

[AUDIT_SAVE, "Backup save slot rotated", [_prevKey], "", ""] call BO_fnc_auditServer;
BO_LOG_INFO("save","Backup save slot rotated");
