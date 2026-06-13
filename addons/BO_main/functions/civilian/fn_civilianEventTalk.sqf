#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventTalk
 *
 * Server-auth reward delivery. Player ACE-Talks an informant; this
 * function is invoked via remoteExec from the client.
 *
 * - Validates the target is a live, registered informant.
 * - Picks a cash reward and credits the player wallet via OT_fnc_money.
 * - Adds +1 influence.
 * - Bumps town stability by +2.
 * - Fires cleanup with reason "talked" (no notify-minor "they left").
 *
 * Idempotent: if the event id has already been cleared (e.g. another
 * player talked first), the early exit on the registry lookup means
 * no double reward.
 *
 * Params:
 *   0: OBJECT - the informant NPC
 *   1: STRING - player UID requesting reward
 */

if (!isServer) exitWith {};

params [["_npc", objNull, [objNull]], ["_uid", "", [""]]];
if (isNull _npc || {!alive _npc}) exitWith {};
if (!(_npc getVariable ["BO_isInformant", false])) exitWith {};

private _eventId = _npc getVariable ["BO_informantEventId", ""];
if (_eventId isEqualTo "") exitWith {};

// Confirm the event is still in the registry; if cleanup already
// fired (e.g. natural expiry race), bail with no payout.
private _active = server getVariable ["BO_activeCivilianEvents", []];
if ((_active findIf { (_x select 0) isEqualTo _eventId }) < 0) exitWith {
    private _raceMsg = format ["civilianEventTalk: event %1 already cleaned, no payout", _eventId];
    BO_LOG_DEBUG("civilian", _raceMsg);
};

private _town = _npc getVariable ["BO_informantTown", ""];

// Reward: base + 0..250 bonus.
private _cashLow = missionNamespace getVariable ["BO_civilianEventRewardCash", 250];
private _cash = _cashLow + floor (random 250);

private _idx = allPlayers findIf { getPlayerUID _x isEqualTo _uid };
if (_idx >= 0) then {
    private _p = allPlayers select _idx;
    [_cash] remoteExec ["OT_fnc_money", _p, false];
    [1] remoteExec ["OT_fnc_influence", _p, false];
    private _toast = format ["The informant tipped you off: +$%1, +1 influence", _cash];
    _toast remoteExec ["OT_fnc_notifyGood", _p, false];
};

if (_town isNotEqualTo "") then {
    [_town, 2] call OT_fnc_stability;
};

private _auditMsg = format ["Informant rewarded in %1 (+$%2)", _town, _cash];
[AUDIT_CIVILIAN, _auditMsg, [_town, _cash, _uid], _uid, ""] call BO_fnc_auditServer;

[_eventId, "talked"] call BO_fnc_civilianEventCleanup;
