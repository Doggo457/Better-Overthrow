// fn_toggleZeus.sqf
//
// Client-side toggle. Three roles:
//   - Host (listen-server player) and LOGGED-IN admin (BIS_fnc_admin
//     == 2): full Zeus. Full is admin-only -- a General who is not
//     host/admin never gets it.
//   - Generals (UID in `server var "generals"`): restricted high-
//     command Zeus (no spawn, no edit/delete, free move orders).
//   - Anyone else: rejected (server double-checks anyway).
//
// The client only REQUESTS; BO_fnc_zeusAssign re-derives the tier
// server-side from owner id / admin state / the generals list, and
// every player gets their own curator module (the old shared module
// meant a second user stole the seat from the first).
//
// On/off state comes from the engine (getAssignedCuratorLogic), not a
// toggle variable -- so a server-side release (e.g. on reconnect)
// can't desync the button. zeusToggle is still written for any legacy
// OT readers.

private _isHost = isServer && hasInterface;
private _isAdmin = (call BIS_fnc_admin) isEqualTo 2;
private _isGeneral = call OT_fnc_playerIsGeneral;

if (!_isHost && !_isAdmin && !_isGeneral) exitWith {
    "You need to be a General or logged-in admin to access Zeus!" call OT_fnc_notifyBig;
};

private _label = ["Zeus (High Command)", "Zeus"] select (_isHost || _isAdmin);

if (isNull (getAssignedCuratorLogic player)) then {
    [player] remoteExec ["BO_fnc_zeusAssign", 2, false];
    zeusToggle = false;
} else {
    [player] remoteExec ["BO_fnc_zeusRelease", 2, false];
    zeusToggle = true;
    (format ["%1 disabled", _label]) call OT_fnc_notifyMinor;
};
