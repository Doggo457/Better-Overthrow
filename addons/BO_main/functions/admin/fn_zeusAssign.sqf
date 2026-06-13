#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zeusAssign
 *
 * Server-authoritative Zeus assignment. The client only ASKS; the tier
 * is resolved here from facts the server can verify itself:
 *
 *   full       -- the hosting player (owner id 2 on a listen server)
 *                 or a LOGGED-IN admin (admin <ownerID> == 2).
 *                 Voted admins and Generals do NOT qualify: full Zeus
 *                 is admin-only, even for Generals.
 *   restricted -- UID present in `server var "generals"`.
 *   neither    -- rejected with a notification.
 *
 * This closes the spoof hole of trusting a client-supplied tier and
 * fixes the multi-user seat-stealing: each player gets their own
 * curator from BO_fnc_acquireZeus.
 *
 * Params: 0: OBJECT player
 */

SERVER_ONLY;
params [["_player", objNull, [objNull]]];
if (isNull _player || {!isPlayer _player}) exitWith {};

private _oid = owner _player;
private _uid = getPlayerUID _player;

private _isHost  = _oid isEqualTo 2;             // listen-server host
private _isAdmin = (admin _oid) isEqualTo 2;     // logged-in admin only
private _isGeneral = _uid in (server getVariable ["generals", []]);

private _tier = "";
if (_isHost || _isAdmin) then { _tier = "full" };
if (_tier isEqualTo "" && {_isGeneral}) then { _tier = "restricted" };

if (_tier isEqualTo "") exitWith {
    "You need to be a General or logged-in admin to access Zeus!"
        remoteExec ["OT_fnc_notifyBig", _oid, false];
};

// Drop any seat this player already holds (tier may have changed).
{
    private _c = _x select 2;
    if (!isNull _c && {(getAssignedCuratorUnit _c) isEqualTo _player}) then {
        unassignCurator _c;
    };
} forEach (missionNamespace getVariable ["BO_zeusRegistry", []]);

private _cur = [_uid, _tier] call BO_fnc_acquireZeus;
if (isNull _cur) exitWith {};

// Defensive: if a stale assignment is stuck on this curator, clear it.
if (!isNull (getAssignedCuratorUnit _cur)) then { unassignCurator _cur };

_player assignCurator _cur;

private _label = ["Zeus (High Command)", "Zeus"] select (_tier isEqualTo "full");
(format ["%1 enabled -- press the Zeus key (Y) to open", _label])
    remoteExec ["OT_fnc_notifyMinor", _oid, false];

private _msg = format ["Zeus assigned: %1 (%2) tier=%3", name _player, _uid, _tier];
[AUDIT_ADMIN, _msg, [_uid, _tier], _uid, name _player] call BO_fnc_auditServer;
BO_LOG_INFO("admin", _msg);
