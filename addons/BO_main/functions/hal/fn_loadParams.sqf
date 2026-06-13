#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_loadParams
 *
 * Read the HAL mission-param surface into missionNamespace globals.
 * BIS_fnc_getParamValue returns the supplied default when the param
 * class is absent (BO convention -- OT's description.ext is binarized,
 * so BO "params" are defaults unless a mission declares them).
 *
 * Server-only. All values session-local; persisted HAL state lives on
 * the `server` namespace (see fn_persist).
 */

SERVER_ONLY;

BO_HAL_enabled          = (["BO_HAL_enabled", 1] call BIS_fnc_getParamValue) isEqualTo 1;
BO_HAL_tickIntervalBase = ["BO_HAL_tickIntervalBase", 1200] call BIS_fnc_getParamValue;
if (BO_HAL_tickIntervalBase < 600)  then { BO_HAL_tickIntervalBase = 600 };
if (BO_HAL_tickIntervalBase > 2400) then { BO_HAL_tickIntervalBase = 2400 };

BO_HAL_maxConcurrentOps = ["BO_HAL_maxConcurrentOps", 4] call BIS_fnc_getParamValue;
if (BO_HAL_maxConcurrentOps < 1) then { BO_HAL_maxConcurrentOps = 1 };
if (BO_HAL_maxConcurrentOps > 8) then { BO_HAL_maxConcurrentOps = 8 };

// -1 auto-detect (modDetect result), 0 force off, 1 force on.
BO_HAL_useLambs = ["BO_HAL_useLambs", -1] call BIS_fnc_getParamValue;
BO_HAL_useVcom  = ["BO_HAL_useVcom", -1] call BIS_fnc_getParamValue;

BO_HAL_disableFOBActions        = (["BO_HAL_disableFOBActions", 0] call BIS_fnc_getParamValue) isEqualTo 1;
BO_HAL_disableGreenforTargeting = (["BO_HAL_disableGreenforTargeting", 0] call BIS_fnc_getParamValue) isEqualTo 1;

// Garrison reinforcements: depleted bases rebuild via interceptable
// convoys (PLAN Phase 3). Master toggle only; thresholds are doctrine.
BO_HAL_garrisonReinforceOn = (["BO_HAL_garrisonReinforce", 1] call BIS_fnc_getParamValue) isEqualTo 1;

// Field-command layer: HAL commands ALL NATO AI. Garrison groups
// defend within a leash of their base; idle field groups become HAL's
// free response pool and eventually consolidate into garrisons.
BO_HAL_commandAll = (["BO_HAL_commandAll", 1] call BIS_fnc_getParamValue) isEqualTo 1;
BO_HAL_garrisonLeash = ["BO_HAL_garrisonLeash", 300] call BIS_fnc_getParamValue;
if (BO_HAL_garrisonLeash < 100) then { BO_HAL_garrisonLeash = 100 };

// v2 surface
// AI-realism preset (build doc section 14 v2 surface): one knob that
// sets the skill of every HAL-spawned unit. 0 relaxed / 1 default / 2 hard.
private _realism = ["BO_HAL_aiRealism", 1] call BIS_fnc_getParamValue;
BO_HAL_skillBase = [0.45, 0.55, 0.7]  param [_realism, 0.55];
BO_HAL_skillSF   = [0.75, 0.85, 0.95] param [_realism, 0.85];

BO_HAL_provocationWeight = ["BO_HAL_provocationWeight", 1.0] call BIS_fnc_getParamValue;
BO_HAL_provocationInterruptThreshold = ["BO_HAL_provocationInterruptThreshold", 0.8] call BIS_fnc_getParamValue;
BO_HAL_fobProbeChance   = ["BO_HAL_fobProbeChance", 0.10] call BIS_fnc_getParamValue;
BO_HAL_fobProbeCooldown = ["BO_HAL_fobProbeCooldown", 21600] call BIS_fnc_getParamValue;

private _msg = format [
    "HAL params: enabled=%1 tickBase=%2 maxOps=%3 lambs=%4 vcom=%5 noFOB=%6 noGreenfor=%7",
    BO_HAL_enabled, BO_HAL_tickIntervalBase, BO_HAL_maxConcurrentOps,
    BO_HAL_useLambs, BO_HAL_useVcom, BO_HAL_disableFOBActions, BO_HAL_disableGreenforTargeting
];
BO_LOG_INFO("hal", _msg);
