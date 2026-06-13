#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_bankAdjust
 *
 * Server-only authoritative read-modify-write of a player's bank
 * balance ("BO_bank") with floor-at-zero clamping. Handles both
 * online and offline targets:
 *   - Online (UID matches an `allPlayers` entry): updates the live
 *     player object via setVariable [..., true] so the broadcast
 *     reaches the owning client.
 *   - Offline: persists the new balance via OT's per-UID
 *     offline-attribute API (`OT_fnc_setOfflinePlayerAttribute`)
 *     under attribute name "BO_bank". This is the SAME shape
 *     OT_fnc_loadPlayerData reads on player connect — a synthetic
 *     `bank<uid>` flat key on players_NS would be dead storage.
 *
 * Intended call site:
 *   [_uid, _delta, "description"] remoteExec ["BO_fnc_bankAdjust", 2, false];
 *
 * Params:
 *   0: STRING - target UID
 *   1: SCALAR - signed delta (positive credits, negative debits)
 *   2: STRING - human-readable audit description
 *
 * Returns: nothing.
 *
 * Side effects:
 *   - mutates target's BO_bank (online) or players_NS bank<uid> (offline)
 *   - audit entry under AUDIT_ATM when delta != 0
 */

SERVER_ONLY;

params [
    ["_uid", "", [""]],
    ["_delta", 0, [0]],
    ["_description", "", [""]]
];

if (_uid isEqualTo "") exitWith {};
if (_delta isEqualTo 0) exitWith {};

private _idx = allPlayers findIf { getPlayerUID _x isEqualTo _uid };
private _newBalance = 0;
private _online = false;

if (_idx >= 0) then {
    private _player = allPlayers select _idx;
    private _current = _player getVariable ["BO_bank", 0];
    _newBalance = (_current + _delta) max 0;
    _player setVariable ["BO_bank", _newBalance, true];
    _online = true;
} else {
    // Offline path: OT's loadPlayerData on connect iterates the
    // per-UID attribute pair-array on players_NS and applies via
    // setVariable. The correct way to write is the OT helper pair
    // (getOfflinePlayerAttribute / setOfflinePlayerAttribute) with
    // attribute name "BO_bank" — the SAME shape the loader reads.
    // A synthetic flat `bank<uid>` key on players_NS is dead storage.
    private _current = [_uid, "BO_bank", 0] call OT_fnc_getOfflinePlayerAttribute;
    _newBalance = (_current + _delta) max 0;
    [_uid, "BO_bank", _newBalance] call OT_fnc_setOfflinePlayerAttribute;
};

[AUDIT_ATM,
 format ["bankAdjust uid=%1 delta=%2 new=%3 online=%4 (%5)",
    _uid, _delta, _newBalance, _online, _description],
 [_uid, _delta, _newBalance, _online, _description],
 "",
 ""
] call BO_fnc_auditServer;
