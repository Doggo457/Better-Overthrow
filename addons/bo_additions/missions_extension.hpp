/*
 * missions_extension.hpp -- bo_additions
 *
 * Adds BO-original mission classes to OT's CfgOverthrowMissions via
 * bare class redeclaration. OT's fn_jobSystem walks every child of
 * CfgOverthrowMissions and registers it in OT_allJobs; the runtime
 * config-merge between OT's config.bin and this file means BO
 * missions appear alongside the OT native ones with no extra
 * dispatch code.
 *
 * To be FOB-requestable a mission must also be listed in
 * BO_fnc_fobJobsDialog's _fobPool array.
 *
 * Target convention for BO raid missions: all use `Town` as the
 * mission-id anchor (FOB dialog handles Town/Base; Town gives a
 * stable per-town id so the same encounter doesn't get reoffered
 * back-to-back). The mission scripts themselves IGNORE the town
 * for placement and put the encounter in wilderness 1.5-3km from
 * the player -- per user spec, these are remote standalone camps,
 * not satellites of existing OT NATO infrastructure.
 *
 * Conditions are minimal: `_inSpawnDistance` is the only check
 * that genuinely matters (you have to be able to interact with
 * the resulting spawn). No NATOabandoned dependency since the
 * camp spawns independent of any existing base/town state.
 */

class CfgOverthrowMissions {

    class BO_RaidSFCamp {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_raidSFCamp.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_HitNATOPatrol {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_hitNATOPatrol.sqf";
        chance      = 30;
        expires     = 4;
        requestable = 1;
    };

    class BO_SabotageDepot {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_sabotageDepot.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_HitCheckpoint {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_hitCheckpoint.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_HitAAA {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_hitAAA.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_SaveMayor {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_saveMayor.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_ProtectDefector {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_protectDefector.sqf";
        chance      = 30;
        expires     = 4;
        requestable = 1;
    };

    class BO_PrisonBreak {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_prisonBreak.sqf";
        chance      = 25;
        expires     = 8;
        requestable = 1;
    };

    class BO_StealNATOTruck {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_stealNATOTruck.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    // Medium-tier officer hit. Town-anchored (the officer is inside
    // a real town building). 25-min effective window -- the OT
    // expires field is in integer minutes; we use 6 to match the
    // SaveMayor cadence and to give the player time to find the
    // building before the "extraction" timeout fires. The 25-min
    // narrative described in the script is a soft target, not a
    // hard config value.
    class BO_KillNATOOfficer {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_killNATOOfficer.sqf";
        chance      = 25;
        expires     = 6;
        requestable = 1;
    };

    // Hard-tier moving convoy ambush. Town-anchored (mission id uses
    // the nearest town for stable per-town anchoring); the convoy
    // actually moves between two nearby NATO-held towns. 60-minute
    // window: ~30 min prep while the convoy hasn't departed yet
    // (player scouts the route from the map markers) + ~30 min
    // active window while the convoy is on the road. The prep timer
    // is enforced by the mission script; OT's expires is the hard
    // ceiling so the job isn't garbage-collected mid-prep.
    class BO_PaydayConvoyAmbush {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_paydayConvoyAmbush.sqf";
        chance      = 25;
        expires     = 60;
        requestable = 1;
    };

    // -- Phase 2 catalog additions --

    class BO_BurnFuelCache {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_burnFuelCache.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_DisableRadar {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_disableRadar.sqf";
        chance      = 25;
        expires     = 6;
        requestable = 1;
    };

    class BO_PlantListeningDevice {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_plantListeningDevice.sqf";
        chance      = 25;
        expires     = 8;
        requestable = 1;
    };

    class BO_StealDocuments {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_stealDocuments.sqf";
        chance      = 25;
        expires     = 8;
        requestable = 1;
    };

    class BO_BurnNATOFlag {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_burnNATOFlag.sqf";
        chance      = 30;
        expires     = 6;
        requestable = 1;
    };

    class BO_DistributeLeaflets {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_distributeLeaflets.sqf";
        chance      = 30;
        expires     = 12;
        requestable = 1;
    };

    class BO_CollaboratorBurglary {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_collaboratorBurglary.sqf";
        chance      = 25;
        expires     = 8;
        requestable = 1;
    };

    class BO_GangLeaderBounty {
        target      = "Town";
        repeatable  = 1;
        condition   = "params ['_inSpawnDistance']; _inSpawnDistance";
        script      = "\overthrow_main\missions\bo_gangLeaderBounty.sqf";
        chance      = 25;
        expires     = 8;
        requestable = 1;
    };

};
