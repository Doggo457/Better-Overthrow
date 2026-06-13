#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_callFireMission
 *
 * Server-auth fire-mission entry point. Re-checks cooldown + bank
 * balance, debits via BO_fnc_bankAdjust, stamps BO_lastFireMission
 * NOW (so the action greys out immediately for all clients), then
 * schedules:
 *   - a 10-30s random preparation delay
 *   - per-round shell spawns at altitude over the target via
 *     createVehicle, tagged BO_playerFireMission=<callerUID> +
 *     BO_fireMissionType=<shell> so BO_fnc_deathHandlerServer
 *     can attribute civilian collateral back to the caller.
 *
 * Cooldown re-check order: cooldown -> balance -> debit -> stamp.
 * If two players race the dialog the second sees the just-set stamp
 * and exits BEFORE bankAdjust runs, so no double-charging.
 *
 * Server-only. Audits at AUDIT_ARTILLERY.
 *
 * Params:
 *   0: OBJECT - mortar
 *   1: STRING - shell type ("HE" / "SMOKE" / "ILLUM")
 *   2: SCALAR - round count
 *   3: ARRAY  - target position
 *   4: STRING - caller UID
 */

SERVER_ONLY;

params [
    ["_mortar", objNull, [objNull]],
    ["_shell", "", [""]],
    ["_count", 0, [0]],
    ["_pos", [0,0,0], [[]]],
    ["_callerUID", "", [""]]
];
if (isNull _mortar) exitWith {};

// Resolve caller UID to a live player object (and its `owner` net id)
// so we can route notifications back. Falls back to broadcast (0) if
// the caller has disconnected.
private _callerIdx = allPlayers findIf { getPlayerUID _x isEqualTo _callerUID };
private _callerObj = if (_callerIdx >= 0) then { allPlayers select _callerIdx } else { objNull };
private _callerOwner = if (!isNull _callerObj) then { owner _callerObj } else { 0 };

// Generals-only -- defensive server-side check in case the client-
// side ACE action gate is bypassed via spoofed remoteExec.
private _generals = server getVariable ["generals", []];
if !(_callerUID in _generals) exitWith {
    if (_callerOwner > 0) then {
        "Only Generals can call fire missions" remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
    private _rmsg = format ["callFireMission rejected: non-General caller uid=%1", _callerUID];
    BO_LOG_WARN("artillery", _rmsg);
};

if (!alive _mortar) exitWith {
    if (_callerOwner > 0) then {
        "Mortar is destroyed" remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
};
if (_count < 1 || {_count > 6}) exitWith {
    BO_LOG_WARN("artillery", "callFireMission rejected: invalid round count");
};

// Cooldown re-check. A race between two callers between dialog open
// and submit is closed here: whoever stamps BO_lastFireMission first
// wins, the second sees the stamp on entry and bails before debiting.
private _last = _mortar getVariable ["BO_lastFireMission", 0];
private _cd   = _mortar getVariable ["BO_mortarCooldown", BO_artilleryCooldownSec];
if ((serverTime - _last) < _cd) exitWith {
    private _remMsg = format ["Fire mission on cooldown (%1s remaining)", round (_last + _cd - serverTime)];
    if (_callerOwner > 0) then {
        _remMsg remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
};

private _spec = BO_artilleryAmmo getOrDefault [_shell, []];
if (_spec isEqualTo []) exitWith {
    private _msg = format ["Unknown shell type '%1' rejected", _shell];
    BO_LOG_WARN("artillery", _msg);
};
_spec params ["_ammoCls", "_perRound"];
private _cost = _count * _perRound;

// Check balance before debit so the player isn't silently zeroed
// when their bank can't cover the mission.
private _bal = 0;
if (!isNull _callerObj) then {
    _bal = _callerObj getVariable ["BO_bank", 0];
} else {
    _bal = [_callerUID, "BO_bank", 0] call OT_fnc_getOfflinePlayerAttribute;
};
if (_bal < _cost) exitWith {
    private _msg = format ["Insufficient bank funds (need $%1, have $%2)", _cost, _bal];
    if (_callerOwner > 0) then {
        _msg remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
};

private _debitDesc = format ["Fire mission %1 x %2", _count, _shell];
[_callerUID, -_cost, _debitDesc] call BO_fnc_bankAdjust;

// Stamp cooldown immediately so the ACE action greys out everywhere.
_mortar setVariable ["BO_lastFireMission", serverTime, true];

private _auditMsg = format ["Fire mission scheduled: %1 x %2 @ %3 by %4 ($%5)",
    _count, _shell, mapGridPosition _pos, _callerUID, _cost];
[AUDIT_ARTILLERY,
    _auditMsg,
    [getPosATL _mortar, _pos, _shell, _count, _callerUID, _cost],
    "",
    ""
] call BO_fnc_auditServer;

// Preparation delay 10-30s. Notify everyone an incoming mission is
// inbound so co-players have a chance to clear the area.
private _prep = 10 + random 20;
private _incomingMsg = format ["Incoming fire mission at grid %1 in ~%2s", mapGridPosition _pos, round _prep];
_incomingMsg remoteExec ["OT_fnc_notifyBig", 0, false];

// Round spacing: 2s for HE/Smoke, 4s for illum (illum needs spacing
// to keep the area lit). Spawn altitude: 400m for impact rounds,
// 250m for illum so it deploys at a sensible flare height.
private _spacing = if (_shell isEqualTo "ILLUM") then { 4 } else { 2 };
private _altitude = if (_shell isEqualTo "ILLUM") then { 250 } else { 400 };

for "_i" from 0 to (_count - 1) do {
    [{
        params ["_ammoCls", "_pos", "_alt", "_shell", "_callerUID", "_mortar"];
        if (isNull _mortar) exitWith {};
        // Per-shell 100m CEP dispersion (uniform disc via sqrt-radius).
        private _ang = random 360;
        private _rad = 100 * sqrt (random 1);
        private _spawnPos = [
            (_pos select 0) + (_rad * sin _ang),
            (_pos select 1) + (_rad * cos _ang),
            (_pos select 2) + _alt
        ];
        private _shellObj = createVehicle [_ammoCls, _spawnPos, [], 0, "CAN_COLLIDE"];
        _shellObj setVelocity [0, 0, -50];
        _shellObj setVariable ["BO_playerFireMission", _callerUID, true];
        _shellObj setVariable ["BO_fireMissionType", _shell, true];
        private _msg = format ["Spawned %1 at %2 (tagged caller=%3)", _ammoCls, _spawnPos, _callerUID];
        BO_LOG_DEBUG("artillery", _msg);
    }, [_ammoCls, _pos, _altitude, _shell, _callerUID, _mortar], _prep + (_i * _spacing)] call CBA_fnc_waitAndExecute;
};
