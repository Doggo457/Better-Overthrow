#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initHAL_modDetect
 *
 * HAL Day 1 prerequisite (PLAN_HAL/HAL_BUILD_ORDER.md §6, addendum
 * locked-decision D3 Option A). Detects whether the optional AI mods
 * LAMBS_Danger and VcomAI are loaded by probing CfgPatches at preInit
 * and stamps the result onto missionNamespace as BO_hasLambsDanger /
 * BO_hasVcom. HAL's per-tick reaction selector reads these flags to
 * decide whether to fan a group out to LAMBS_main_fnc_taskRush / a
 * Vcom escalation script, or fall back to the vanilla doMove / doFire
 * codepath.
 *
 * Runs on BOTH server and every client (hasInterface) so that
 * client-local probes (eg. the future Recon dialog showing "AI: LAMBS
 * enabled") can read the same flag without a JIP roundtrip. CfgPatches
 * is identical on every machine in a server-locked addon set, so the
 * two reads cannot disagree.
 *
 * Class names verified against:
 *   - LAMBS_Danger.fsm: addons/lambs_main/config.cpp -> class lambs_main
 *   - Vcom AI V3.4.0:   addons/vcomai/config.cpp     -> class vcomai
 *
 * Side effects:
 *   - sets BO_hasLambsDanger (bool) on missionNamespace
 *   - sets BO_hasVcom        (bool) on missionNamespace
 *   - emits one INFO audit-log line so the RPT records the detected
 *     environment per machine (server + each JIP)
 *
 * Idempotent: subsequent invocations just re-stamp the same booleans.
 *
 * NOT a SERVER_ONLY function -- intentionally runs on the dedicated
 * server, the host (which is both), and JIP clients. The preInit
 * dispatcher invokes it on every machine.
 */

if (!isServer && !hasInterface) exitWith {};

private _hasLambs = isClass (configFile >> "CfgPatches" >> "lambs_main");
private _hasVcom  = isClass (configFile >> "CfgPatches" >> "vcomai");

BO_hasLambsDanger = _hasLambs;
BO_hasVcom        = _hasVcom;

private _msg = format [
    "HAL modDetect: lambs_main=%1 vcomai=%2 (server=%3 hasInterface=%4)",
    _hasLambs, _hasVcom, isServer, hasInterface
];
BO_LOG_INFO("init", _msg);
