#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_init
 *
 * Server boot for the HAL strategic layer. Called once from
 * BO_fnc_postInit after OT_serverInitDone (so OT_NATO_* faction vars,
 * NATOresources and the town/objective tables all exist).
 *
 * Lifetimes:
 *   server namespace (auto-saved by OT's server-var walk):
 *     BO_HAL_heatByRegion   [[town, heat0..1], ...]
 *     BO_HAL_opCounter      NUMBER (monotonic op ids)
 *     BO_HAL_fobRegistry    [[posKey, name, pos, lastProbeServerTime], ...]
 *     BO_HAL_silentTicks    NUMBER (zeroed on LOAD by postLoadHydrate, D3)
 *   missionNamespace (session-only, rebuilt each boot):
 *     BO_HAL_lastTick, BO_HAL_activeOps, BO_HAL_provocationQueue,
 *     BO_HAL_tempo, BO_HAL_consistency, BO_HAL_lastKnown,
 *     BO_HAL_riflePool, BO_HAL_lambsActive, BO_HAL_vcomActive,
 *     BO_HAL_fobActionActive
 */

SERVER_ONLY;

[] call BO_HAL_fnc_loadParams;

// Runtime master switch (Options menu) persists across save/load and
// overrides the mission param. NOTE: init no longer early-exits when
// disabled -- state is seeded and the PFHs installed regardless (each
// self-gates on BO_HAL_enabled), so the toggle works mid-session both
// ways without a mission restart.
private _override = server getVariable "BO_HAL_enabledOverride";
if (!isNil "_override" && {_override isEqualType true}) then {
    BO_HAL_enabled = _override;
};
publicVariable "BO_HAL_enabled"; // clients read it for the Options label

if (!BO_HAL_enabled) then {
    BO_LOG_INFO("hal", "HAL starting DISABLED (param/override); toggle lives in Options");
};

// ---- session state -------------------------------------------------
BO_HAL_lastTick         = 0;
BO_HAL_activeOps        = [];
BO_HAL_provocationQueue = [];
BO_HAL_tempo            = 0;
BO_HAL_consistency      = 0.05;
BO_HAL_lastKnown        = [];      // [pos, time, heading] of freshest sighting
BO_HAL_aarRing          = [];
BO_HAL_fobActionActive  = false;
BO_HAL_partialPending   = false;

// ---- persisted state (seed only when absent) -----------------------
if (isNil { server getVariable "BO_HAL_heatByRegion" }) then {
    server setVariable ["BO_HAL_heatByRegion", []];
};
// Working copy; fn_persist flushes it back each tick.
BO_HAL_heatCache = server getVariable ["BO_HAL_heatByRegion", []];
if (isNil { server getVariable "BO_HAL_opCounter" }) then {
    server setVariable ["BO_HAL_opCounter", 0];
};
if (isNil { server getVariable "BO_HAL_fobRegistry" }) then {
    server setVariable ["BO_HAL_fobRegistry", []];
};
if (isNil { server getVariable "BO_HAL_silentTicks" }) then {
    server setVariable ["BO_HAL_silentTicks", 0, true];
};
// War Level: independent aggression dial (Antistasi-style), NOT the
// resources ledger. Seed at 1; migrate old campaigns once from the
// legacy resources-derived dial so they don't restart cold.
if (isNil { server getVariable "BO_warLevel" }) then {
    private _legacy = ((server getVariable ["NATOresources", 300]) / 300) min 10 max 1;
    server setVariable ["BO_warLevel", _legacy, true];
};
// Session combat-response memory: recent defeats per area
// ([pos, serverTime, pkgId]); drives suppression + response variety.
BO_HAL_setbacks = [];

// Adopt already-registered FOBs (boot after load, or HAL enabled
// mid-campaign): fold `bases` entries into the registry.
{ [_x] call BO_HAL_fnc_fobTouch } forEach (server getVariable ["bases", []]);

// ---- LAMBS / VCOM contract -----------------------------------------
// modDetect ran at preInit; params can force either way.
BO_HAL_lambsActive = switch (BO_HAL_useLambs) do {
    case 0:  { false };
    case 1:  { true };
    default  { missionNamespace getVariable ["BO_hasLambsDanger", false] };
};
BO_HAL_vcomActive = switch (BO_HAL_useVcom) do {
    case 0:  { false };
    case 1:  { true };
    default  { missionNamespace getVariable ["BO_hasVcom", false] };
};

// VCOM globals once VCOM has bootstrapped (locked decision: HAL/LAMBS
// own movement + suppression; VCOM keeps artillery). Only touched while
// HAL is enabled -- fn_setEnabled re-applies them on a live enable.
if (BO_HAL_vcomActive && BO_HAL_enabled) then {
    [{ !isNil "Vcm_Settings" }, {
        VCM_AISUPPRESS = false;
        VCM_ADVANCEDMOVEMENT = false;
        VCM_StealVeh = false;
        VCM_MINEENABLED = false;
        VCM_ARTYENABLE = true;
        BO_LOG_INFO("hal", "VCOM globals set (suppress/advmove/stealveh/mines off, arty on)");
    }, []] call CBA_fnc_waitUntilAndExecute;
};

// ---- faction rifle pool --------------------------------------------
// Locked decision #16: packages derive every class from OT_NATO_* at
// dispatch; rank-and-file riflemen aren't covered by a scalar, so mine
// them from the faction's CfgGroups infantry (same source OT itself
// mines OT_NATO_GroundForces from). Crew/pilot/UAV entries excluded.
private _pool = [];
{
    {
        private _cls = getText (_x >> "vehicle");
        if (_cls isNotEqualTo "") then {
            private _l = toLower _cls;
            if (((_l find "crew") < 0) && {(_l find "pilot") < 0} && {(_l find "uav") < 0}
                && {(_l find "helipilot") < 0} && {!(_cls in _pool)}) then {
                _pool pushBack _cls;
            };
        };
    } forEach ("true" configClasses _x);
    if (count _pool > 24) exitWith {};
} forEach (missionNamespace getVariable ["OT_NATO_GroundForces", []]);

if (_pool isEqualTo []) then {
    // Faction shipped no minable infantry groups: fall back to the
    // scalar leaders so packages still field SOMETHING coherent.
    {
        private _v = missionNamespace getVariable [_x, ""];
        if (_v isEqualType "" && {_v isNotEqualTo ""}) then { _pool pushBack _v };
    } forEach ["OT_NATO_Unit_TeamLeader", "OT_NATO_Unit_SquadLeader"];
};
BO_HAL_riflePool = _pool;

private _pmsg = format ["HAL rifle pool mined: %1 classes (lambs=%2 vcom=%3)",
    count _pool, BO_HAL_lambsActive, BO_HAL_vcomActive];
BO_LOG_INFO("hal", _pmsg);

// ---- heartbeat ------------------------------------------------------
// Cheap PFH every 30s; fn_tick gates itself on the garrison-scaled
// interval and the provocation layer can force a partial pass.
[{
    if (!BO_HAL_enabled) exitWith {};
    if (BO_HAL_partialPending) then {
        BO_HAL_partialPending = false;
        ["partial"] call BO_HAL_fnc_tick;
    } else {
        [] call BO_HAL_fnc_tick;
    };
}, 30] call CBA_fnc_addPerFrameHandler;

// AI-reliability watchdog (Layer 2 + Layer 4), 45s cadence.
[{ call BO_HAL_fnc_watchdog }, 45] call CBA_fnc_addPerFrameHandler;

// Reactive op evaluation, 60s cadence. Originally ops were only
// evaluated inside the 20-min strategic tick, which made arrivals,
// dismounts, retreats, reinforcement and interdiction resolution
// glacial -- the build doc's reactive layer was always meant to run
// at seconds, not tick, scale.
[{
    if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};
    { [_x] call BO_HAL_fnc_evaluateOp } forEach (+BO_HAL_activeOps);
}, 60] call CBA_fnc_addPerFrameHandler;

// Field command: garrison leash + standing-army adoption, 60s cadence.
BO_HAL_fieldPool = [];
if (BO_HAL_commandAll) then {
    [{ call BO_HAL_fnc_fieldCommand }, 60] call CBA_fnc_addPerFrameHandler;
};

// Campaign layer: the regional commander (decapitation target), the
// physical supply line (NATO's only income) + last-stand scheduler,
// and the doctrine cache seed.
[] call BO_HAL_fnc_commanderInit;
[] call BO_HAL_fnc_supplyInit;
call BO_HAL_fnc_doctrineTraits;

["boot", []] call BO_HAL_fnc_aar;
BO_LOG_INFO("hal", "HAL alive: heartbeat 30s, watchdog 45s");
