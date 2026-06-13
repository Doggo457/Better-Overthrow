#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_commanderInit
 *
 * Decapitation-strike system (user-locked design):
 *
 *   A named HAL Regional Commander exists at ONE random NATO base,
 *   inside a random building, behind a hardened security detail:
 *   extra garrison fireteams, extra armed vehicles, and a CONSTANT
 *   attack-helicopter patrol orbiting the base. Kill him and HAL is
 *   DISRUPTED -- consistency floors at 0.05 (the tick reads
 *   BO_HAL_disruptedUntil), heat memory is wiped, and the whole
 *   island hears about it (Overthrow notifications). NATO appoints a
 *   replacement at ANOTHER random base 60 real minutes later.
 *
 * The entourage is physical only while a player is near the base
 * (presence PFH below) -- the commander's existence and base choice
 * persist as server vars; the bodyguard detail rebuilds on approach.
 * All classes derive from OT_NATO_* (multi-nation).
 *
 * State (server vars, auto-persisted; serverTime stamps self-clamp):
 *   BO_HAL_cmdBase       STRING base name ("" = none alive/spawned)
 *   BO_HAL_cmdAlive      BOOL
 *   BO_HAL_cmdRespawnAt  NUMBER serverTime (0 = n/a)
 *   BO_HAL_disruptedUntil NUMBER serverTime
 */

SERVER_ONLY;

if (missionNamespace getVariable ["BO_HAL_cmdInit", false]) exitWith {};
missionNamespace setVariable ["BO_HAL_cmdInit", true];

BO_HAL_cmdObjects = [];   // session-only live entourage handles
BO_HAL_cmdSpawned = false;

// Stale serverTime clamps (prior-session stamps).
private _ra = server getVariable ["BO_HAL_cmdRespawnAt", 0];
if (_ra > serverTime + 3700) then { server setVariable ["BO_HAL_cmdRespawnAt", serverTime + 600] };
private _du = server getVariable ["BO_HAL_disruptedUntil", 0];
if (_du > serverTime + 3700) then { server setVariable ["BO_HAL_disruptedUntil", 0] };

// Seed: no commander on record -> appoint one now, quietly.
if (server getVariable ["BO_HAL_cmdBase", ""] isEqualTo ""
    && {!(server getVariable ["BO_HAL_cmdAlive", false])}
    && {(server getVariable ["BO_HAL_cmdRespawnAt", 0]) isEqualTo 0}) then {
    [false] call BO_HAL_fnc_commanderAppoint;
};

// Presence + lifecycle PFH (20s): spawn the detail when players close
// on the commander's base, despawn when they leave, run the 60-min
// replacement clock.
[{
    if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};
    private _now = serverTime;

    // Replacement clock.
    private _ra = server getVariable ["BO_HAL_cmdRespawnAt", 0];
    if (_ra > 0 && {_now >= _ra}) then {
        server setVariable ["BO_HAL_cmdRespawnAt", 0];
        [true] call BO_HAL_fnc_commanderAppoint;
    };

    private _base = server getVariable ["BO_HAL_cmdBase", ""];
    if (_base isEqualTo "" || {!(server getVariable ["BO_HAL_cmdAlive", false])}) exitWith {
        if (BO_HAL_cmdSpawned) then { [] call BO_HAL_fnc_commanderDespawn };
    };

    // Base fell to the rebels? The commander relocates immediately.
    if (_base in (server getVariable ["NATOabandoned", []])) exitWith {
        if (BO_HAL_cmdSpawned) then { [] call BO_HAL_fnc_commanderDespawn };
        [false] call BO_HAL_fnc_commanderAppoint;
    };

    private _pos = missionNamespace getVariable ["BO_HAL_cmdPos", []];
    if (_pos isEqualTo []) exitWith {};
    private _near = ((allPlayers select { alive _x }) findIf {
        (_x distance2D _pos) < (OT_spawnDistance + 400)
    }) != -1;

    if (_near && {!BO_HAL_cmdSpawned}) then { [] call BO_HAL_fnc_commanderSpawn };
    if (!_near && {BO_HAL_cmdSpawned}) then {
        // 2-minute grace so edge-of-bubble players don't strobe it.
        private _since = missionNamespace getVariable ["BO_HAL_cmdNoPlayerSince", -1];
        if (_since < 0) then {
            missionNamespace setVariable ["BO_HAL_cmdNoPlayerSince", _now];
        } else {
            if ((_now - _since) > 120) then { [] call BO_HAL_fnc_commanderDespawn };
        };
    } else {
        missionNamespace setVariable ["BO_HAL_cmdNoPlayerSince", -1];
    };
}, 20] call CBA_fnc_addPerFrameHandler;

BO_LOG_INFO("hal", "Commander system online");
