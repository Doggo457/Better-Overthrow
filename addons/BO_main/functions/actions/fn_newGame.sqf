closeDialog 0;

// BO: clean slate. Without this, the first save after New Game rotates
// the prior campaign's full payload into the .prev backup slot -- and
// the prior main slot survives until the new save commits. Wipe both
// (main + .prev) before flagging the StartupType so "New Game" really
// starts from zero.
private _saveName = if (!isNil "OT_saveName") then { OT_saveName } else { "" };
if (_saveName isNotEqualTo "") then {
    missionProfileNamespace setVariable [_saveName, nil];
    missionProfileNamespace setVariable [_saveName + ".prev", nil];
    // Old saves lived on profileNamespace; clear there too in case the
    // user is upgrading from a pre-missionProfileNamespace install.
    profileNamespace setVariable [_saveName, nil];
    profileNamespace setVariable [_saveName + ".prev", nil];
    saveMissionProfileNamespace;
    saveProfileNamespace;
};

"Generating economy" remoteExec ['OT_fnc_notifyStart', 0, false];
[] spawn OT_fnc_initEconomy;
waitUntil { !isNil "OT_economyInitDone" };
server setVariable ["StartupType", "NEW", true];
