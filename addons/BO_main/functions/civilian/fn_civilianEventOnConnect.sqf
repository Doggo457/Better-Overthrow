#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventOnConnect
 *
 * Server-side JIP handler wired through CBA's onPlayerConnected.
 * For each live active informant event, remoteExec a marker create
 * to the connecting client. Same for unexpired sabotage history
 * entries (24h map intel reveal).
 *
 * Params come straight from onPlayerConnected:
 *   0: SCALAR - id
 *   1: STRING - uid
 *   2: STRING - name
 *   3: BOOL   - jip
 *   4: SCALAR - owner / network id
 */

if (!isServer) exitWith {};

params [
    ["_id", -1, [0]],
    ["_uid", "", [""]],
    ["_name", "", [""]],
    ["_jip", false, [false]],
    ["_owner", 0, [0]]
];

if (_owner < 2) exitWith {}; // skip server / headless

// Replay active informant markers.
private _active = server getVariable ["BO_activeCivilianEvents", []];
{
    _x params ["", "_town", "_npc", "", "_markerId"];
    if (!isNull _npc && {alive _npc}) then {
        [_markerId, getPosATL _npc, _town] remoteExec ["BO_fnc_civilianEventMarker", _owner, false];
    };
} forEach _active;

// Replay unexpired sabotage map intel (24 in-game hours).
private _history = server getVariable ["BO_sabotageHistory", []];
private _nowNum = dateToNumber date;
// Year fraction for 24 in-game hours = 1 / 365.
private _dayInNum = 1 / 365;
{
    _x params ["_evDate", "_baseName", "_effect", ""];
    if ((_nowNum - dateToNumber _evDate) < _dayInNum) then {
        [_baseName, _effect] remoteExec ["BO_fnc_sabotageMarker", _owner, false];
    };
} forEach _history;
