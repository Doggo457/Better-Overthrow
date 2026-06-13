#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initGarbageCollector
 *
 * Registers two server-side hooks:
 *
 *   1. EntityKilled event — tags every newly dead unit with the
 *      timestamps needed for the proximity-based cleanup sweep.
 *
 *   2. BO_garbage_collector action loop — runs every ~30s, walks
 *      allDeadMen, deletes corpses that no player has approached
 *      within BO_corpseDecayRadius for BO_corpseDecaySeconds.
 *
 * Setting BO_corpseDecaySeconds to -1 (mission param "Off") disables
 * the loop entirely. The existing 300-body emergency sweep at
 * OT GUERLoop:192-195 remains as a last-resort fallback.
 */

SERVER_ONLY;

// Honor "off" setting.
if (BO_corpseDecaySeconds < 0) exitWith {
    BO_LOG_INFO("garbage","Garbage collector disabled by mission param");
};

// 1. EntityKilled tagging.
addMissionEventHandler ["EntityKilled", {
    params ["_unit"];
    if (!isNull _unit && {_unit isKindOf "CAManBase"} && {!isPlayer _unit}) then {
        [_unit] call BO_fnc_tagCorpseOnDeath;
    };
}];

// 2. Sweep loop.
[
    "BO_garbage_collector",
    "_counter % 18 isEqualTo 0",          // ~30s at OT's 1.65s tick rate
    "[] call BO_fnc_garbageCollectorTick"
] call OT_fnc_addActionLoop;

private _initMsg = format ["Garbage collector initialized (decay=%1s, radius=%2m)",
    BO_corpseDecaySeconds, BO_corpseDecayRadius];
BO_LOG_INFO("garbage", _initMsg);
