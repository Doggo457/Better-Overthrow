#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_noteLoss
 *
 * NATO casualty feed (replaces the draft's separate loss ring: losses
 * fold straight into regional heat). Called from fn_deathHandler when
 * the victim is WEST. Self-forwards to the server.
 *
 * Params: 0: ARRAY pos of the loss
 */

if (!isServer) exitWith { _this remoteExec ["BO_HAL_fnc_noteLoss", 2, false] };
if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};

params [["_pos", [0,0,0], [[]]]];
[_pos, 0.15] call BO_HAL_fnc_heatBump;
[0.04, "NATO casualty"] call BO_HAL_fnc_warLevelBump;
