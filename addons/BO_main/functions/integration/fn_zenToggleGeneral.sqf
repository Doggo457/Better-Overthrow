#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenToggleGeneral
 *
 * Zen right-click context action handler. Toggles the General flag
 * on the hovered player without going through the resistance-dialog
 * "Make General" path (which is host/admin only).
 *
 * Server-auth: clients invoke via remoteExec to server. The Zeus
 * context-menu registration is in BO_fnc_initZenContextMenu.
 *
 * Params:
 *   0: OBJECT - hovered player
 */

if (!isServer) exitWith {};

// Server-side privilege check: the UI condition gates the menu entry,
// but a remoteExec can be forged. Accept only calls from the server
// itself (0), the hosting player (2), or a LOGGED-IN admin client.
// Generals do not qualify -- the role chain stops at admin.
private _ro = remoteExecutedOwner;
if (_ro > 2 && {(admin _ro) isNotEqualTo 2}) exitWith {
    private _wmsg = format ["zenToggleGeneral: rejected non-admin caller (owner %1)", _ro];
    BO_LOG_WARN("admin", _wmsg);
};

params [["_target", objNull, [objNull]]];
if (isNull _target || {!isPlayer _target}) exitWith {};

private _uid = getPlayerUID _target;
if (_uid isEqualTo "") exitWith {};

private _generals = server getVariable ["generals", []];
private _wasGeneral = _uid in _generals;
if (_wasGeneral) then {
    _generals = _generals - [_uid];
} else {
    _generals pushBack _uid;
};
server setVariable ["generals", _generals, true];

private _name = name _target;
private _verb = if (_wasGeneral) then { "demoted" } else { "promoted" };
private _msg = format ["Zeus %1 %2 %3 General", _verb, _name, if (_wasGeneral) then { "from" } else { "to" }];
_msg call OT_fnc_notifyMinor;
[AUDIT_ADMIN, _msg, [_uid, _name, _verb], "", ""] call BO_fnc_auditServer;
private _logMsg = format ["Zen toggle-general: %1 (%2) -> %3", _name, _uid, !_wasGeneral];
BO_LOG_INFO("admin", _logMsg);
