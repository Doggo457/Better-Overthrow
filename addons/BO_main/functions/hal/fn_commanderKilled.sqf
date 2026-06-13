#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_commanderKilled
 *
 * The decapitation payoff. Server-side (MPKilled body remoteups here):
 *
 *   - Overthrow notification to EVERYONE (user-locked)
 *   - HAL is DISRUPTED for the 60-min interregnum: the tick floors
 *     consistency at 0.05 while serverTime < BO_HAL_disruptedUntil
 *   - heat memory wiped (the network's picture dies with him)
 *   - War Level -1.5 (command paralysis)
 *   - replacement appointed at ANOTHER random base in 60 real minutes
 *
 * Params: 0: OBJECT the dead commander
 */

SERVER_ONLY;
params [["_unit", objNull, [objNull]]];

// Re-entry guard (MPKilled can fire alongside other death paths).
if (!(server getVariable ["BO_HAL_cmdAlive", false])) exitWith {};

private _base = server getVariable ["BO_HAL_cmdBase", ""];
server setVariable ["BO_HAL_cmdAlive", false, true];
server setVariable ["BO_HAL_cmdBase", "", true];
server setVariable ["BO_HAL_cmdRespawnAt", serverTime + 3600];
server setVariable ["BO_HAL_disruptedUntil", serverTime + 3600];

// The network's institutional memory dies with him.
BO_HAL_heatCache = [];
call BO_HAL_fnc_persist;
[-1.5, "commander eliminated"] call BO_HAL_fnc_warLevelBump;

"NATO REGIONAL COMMANDER ELIMINATED" remoteExec ["OT_fnc_notifyBig", 0, false];
"NATO command is in disarray -- expect a weak response for the next hour"
    remoteExec ["OT_fnc_notifyGood", 0, false];

["commander_killed", [_base]] call BO_HAL_fnc_aar;
private _msg = format ["HAL Commander KILLED at %1 -- disrupted 60min, successor inbound", _base];
BO_LOG_INFO("hal", _msg);
[AUDIT_ADMIN, _msg, [_base], "", ""] call BO_fnc_auditServer;

// The leaderless detail falls back to field-command custody: strip the
// hands-off sentinel so fieldCommand adopts and marches them away.
{
    if (!isNull _x && {alive _x} && {_x isKindOf "Man"}) then {
        (group _x) setVariable ["BO_HAL_op", nil, false];
    };
} forEach BO_HAL_cmdObjects;
BO_HAL_cmdSpawned = false;   // objects stay in-world; custody transferred
BO_HAL_cmdObjects = [];
