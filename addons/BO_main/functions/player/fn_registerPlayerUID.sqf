#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_registerPlayerUID
 *
 * Server-authoritative push of a player UID into the OT_allplayers
 * roster on players_NS. The original client-side code in
 * fn_initPlayerLocal performed a non-atomic get/append/set, which
 * loses entries when two JIPs init concurrently (last write wins).
 * Routing through the server serialises the read-modify-write and
 * also lets us co-locate the per-UID name<->uid map updates that
 * must stay consistent with the roster.
 *
 * Intended call site (from client):
 *   [_uid, _name] remoteExec ["BO_fnc_registerPlayerUID", 2, false];
 *
 * Params:
 *   0: STRING - player UID
 *   1: STRING - player display name (used for the name<->uid map)
 *
 * Returns: nothing.
 *
 * Side effects:
 *   - mutates players_NS "OT_allplayers", "name<uid>", "uid<name>"
 */

SERVER_ONLY;

params [
    ["_uid", "", [""]],
    ["_name", "", [""]]
];

if (_uid isEqualTo "") exitWith {};

private _aplayers = players_NS getVariable ["OT_allplayers", []];
if !(_uid in _aplayers) then {
    _aplayers pushBack _uid;
    players_NS setVariable ["OT_allplayers", _aplayers, true];
};

if (_name isNotEqualTo "") then {
    players_NS setVariable [format ["name%1", _uid], _name, true];
    players_NS setVariable [format ["uid%1", _name], _uid, true];
};
