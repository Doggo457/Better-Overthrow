/*
 * config.cpp -- bo_additions
 *
 * Companion addon to overthrow_main. Registers BO's additions:
 * banking (ATMs), audit log, garbage collector, modded-pricing
 * resolver, and the post-load hydrate / requestSave save hooks.
 */

class CfgPatches {
    class BO_Additions {
        name = "Better Overthrow -- additions";
        author = "Better Overthrow contributors";
        units[] = {};
        weapons[] = {};
        magazines[] = {};
        requiredVersion = 2.12;
        requiredAddons[] = {
            "OT_Overthrow_Main",
            "cba_main",
            "ace_main"
        };
        version = "0.1.0.0";
        versionStr = "0.1.0.0";
    };
};

class CfgFunctions {
    class BO {

        class Init {
            file = "\overthrow_main\functions\init";
            class preInit { preInit = 1; };
            class postInit { postInit = 1; };
            class initAuditLog {};
            class initPricing {};
            class initGarbageCollector {};
            // HAL Day 1 prerequisite. Runs at preInit on every machine
            // (server + clients) so BO_hasLambsDanger / BO_hasVcom are
            // populated before HAL's per-tick selector or any UI probe
            // reads them. See PLAN_HAL/HAL_BUILD_ORDER.md §6.
            class initHAL_modDetect { preInit = 1; };
        };

        class Log {
            file = "\overthrow_main\functions\log";
            class log {};
            class audit {};
            class auditServer {};
            class auditGroup {};
            class recordMetric {};
            class formatTimestamp {};
            class exportAudit {};
        };

        class Logging {
            file = "\overthrow_main\functions\logging";
            class logMissionDebris {};
            class logMissionDebrisInit {};
        };

        class Save {
            file = "\overthrow_main\functions\save";
            class postLoadHydrate {};
            class requestSave {};
            class backupSave {};
            class restorePrevSave {};
            class verifyIntegrity {};
            class flattenContainerCargo {};
        };

        class ATM {
            file = "\overthrow_main\functions\atm";
            class atmDialog {};
            class bankDeposit {};
            class bankWithdraw {};
            class bankTransferPlayer {};
            class bankReceivePlayerTransfer {};
            class getBankBalance {};
            class isNATOControlledATM {};
            class addATMActions {};
            class bankAdjust {};
        };

        class Build {
            file = "\overthrow_main\functions\actions";
            class initFactory {};
            class replaceStructureCrate {};
            class renameFOB {};
            class commitNewFOB {};
            class registerBase {};
            class renameBase {};
            class addSquad {};
            class addRecruit {};
            class removeRecruitsByUnits {};
            class adjustTownCounter {};
            class registerWarehouse {};
            class factoryQueueAdjust {};
            class buyBusinessServer {};
            // Server-auth resolver for fn_buy's three shared-state
            // mutations: faction standing (dealer rep bump on shop buy),
            // GEURblueprints pushBack (vehicle/aircraft blueprint unlock,
            // idempotent on duplicates), and the reschems delta on
            // explosive buys (the security-critical anti-double-spend
            // path). Previously unregistered -- so the remoteExecs at
            // fn_buy.sqf:23/52/174 silently no-op'd: dealer rep never
            // climbed, blueprints never unlocked (charged on every
            // retry), and explosives were free of chems cost. Same
            // failure-mode + fix as adjustResistanceFunds below.
            class resolveBuy {};
        };

        // Multi-factory production system (per-object state, budgeted
        // round-robin PFH). Replaces the GUERLoop single-factory tick.
        class Factories {
            file = "\overthrow_main\functions\factories";
            class factoryLoop {};
            class factoryTick {};
            class factoryProduceOne {};
            class registerFactory {};
            class unregisterFactory {};
            class factoryEnsureOutputContainer {};
            class factoryVehicleSpawnPos {};
            class factoryQueueAddTarget {};
            class factoryQueueRemoveTarget {};
            class factoryQueueClearTarget {};
        };

        // Production businesses (Phase 2). Same per-object-state +
        // chunked round-robin PFH model as factories. Each type has
        // a thin init wrapper so the slot-6 OT_init replay carries
        // the type implicitly through the wrapper's name.
        class Businesses {
            file = "\overthrow_main\functions\businesses";
            class initBusiness {};
            class initLumberyard {};
            class initMine {};
            class initVineyard {};
            class initWinery {};
            class initOlivePlantation {};
            class initChemicalPlant {};
            class registerBusiness {};
            class unregisterBusiness {};
            class businessEnsureCrate {};
            class businessLoop {};
            class businessTick {};
            class spawnBusinessWorker {};
        };

        class Admin {
            file = "\overthrow_main\functions\admin";
            // Multi-user Zeus: per-player curators + server-side
            // privilege validation (full = host/admin only).
            class acquireZeus {};
            class zeusAssign {};
            class zeusRelease {};
            class initRestrictedZeus {};
        };

        class BOPlayer {
            file = "\overthrow_main\functions\player";
            class registerPlayerUID {};
        };

        class Zen {
            file = "\overthrow_main\functions\integration";
            class zenSetMoneyModule {};
            class zenSetBankModule {};
            class zenSetWarLevelModule {};
            class zenSetNATOResourcesModule {};
            class zenHalModule {};
            class zenSetBankContext {};
            class initZenContextMenu {};
            // Phase 2 ZEN extensions.
            class zenSpawnBusiness {};
            class zenSpawnFactory {};
            class zenTriggerDemandEvent {};
            class zenSetTownPolice {};
            class zenSetGarrison {};
            class zenTriggerCounterAttack {};
            class zenToggleGeneral {};
        };

        // NATO Police Stations (Phase 2). Virtualized garrison spawns
        // on player approach via OT_fnc_registerSpawner. Capture is
        // flag-triggered: scroll-action on a NATO flag outside the
        // station starts a town-style capture with circle marker and
        // a wave of reinforcements from the nearest other station.
        // Recapture fires from BO_fnc_NATOCounterTown's success branch.
        class Police {
            file = "\overthrow_main\functions\police";
            // postLoad hydrate for BO_natoPoliceStations. NetIds (slots
            // 3/5/9), markers (slot 7), flag, and spawner registrations
            // don't survive save/load; this rebinds them from the
            // persistent slot-0/1/2/8/11 fields. Captured rows stay
            // marker-less/flag-less; uncaptured rows get marker + flag
            // + fresh spawner. Declared first so the LOAD-path skip gate
            // in initNATOPoliceStations finds a populated registry.
            class postLoadHydratePolice {};
            class initNATOPoliceStations {};
            class spawnNATOPoliceStation {};
            class spawnPoliceStationGarrison {};
            class startPoliceStationCapture {};
            class dispatchPoliceReinforcements {};
            class captureNATOPoliceStation {};
            class failPoliceStationCapture {};
            class recaptureNATOPoliceStation {};
            class polCaptureHUD {};
        };

        class Recon {
            file = "\overthrow_main\functions\virtualization";
            class reconSnapshot {};
            class reconRestore {};
            class clearReconState {};
        };

        class BOCleanup {
            file = "\overthrow_main\functions\cleanup";
            class garbageCollectorTick {};
            class tagCorpseOnDeath {};
        };

        class BOEvents {
            file = "\overthrow_main\functions\events";
            class deathHandlerServer {};
            class worldEventsInit {};
            class worldEventsLoop {};
            class worldEventsTick {};
            class worldEventMultiplier {};
        };

        class Loadout {
            file = "\overthrow_main\functions\loadout";
            class savePlayerLoadout {};
            class loadPlayerLoadout {};
            class copyLoadoutFromPlayer {};
            class resetLoadoutToDefault {};
            class listPlayerTemplates {};
        };

        class BOEconomy {
            file = "\overthrow_main\functions\economy";
            class resolvePrice {};
            class loadPricePack {};
            class setPrice {};
            class lookupMagazineEquivalent {};
            class lookupFactionAverage {};
            class priceFallbackHeuristic {};
            // Server-auth resistance-funds adjuster. Previously unregistered
            // so fn_giveFunds' remoteExec was a silent no-op; donations
            // vanished into the void. Register here so the function actually
            // exists at runtime.
            class adjustResistanceFunds {};
        };

        class BODialogs {
            file = "\overthrow_main\functions\UI\dialogs";
            class auditViewerDialog {};
            class loadoutTemplatesDialog {};
            class fobJobsDialog {};
            class logisticsNetworkDialog {};
            class logisticsRouteDialog {};
            class logisticsRouteDialogSetMode {};
            class logisticsRouteDialogToggleSkip {};
            class logisticsRouteDialogPreview {};
            class logisticsRouteDialogSubmit {};
            class garageDialog {};
            class reconDialog {};
        };

        // Persistent garage + vehicle insurance (Phase 2).
        // Server-auth Store/Retrieve/Insure/CancelInsurance, the per-
        // vehicle Killed EH installer, the client-side ACE action
        // installer, and the postLoad rehydrate that re-installs the
        // Killed EH on insured vehicles after a save/load round-trip.
        class Garage {
            file = "\overthrow_main\functions\garage";
            class garageStore {};
            class garageRetrieve {};
            class garageInsure {};
            class garageCancelInsurance {};
            class installInsuranceKilledEH {};
            class garageInstallActions {};
            class postLoadHydrateGarage {};
        };

        // Recon flights / paid intel (Phase 2). Server fn debits cash
        // + bumps NATOresources + writes BO_activeRecon; client fns
        // arm the local map reveal + countdown HUD on broadcast.
        class ReconIntel {
            file = "\overthrow_main\functions\recon";
            class reconPurchase {};
            class reconClientArm {};
            class reconRebuildClient {};
            class reconCostPreview {};
            class reconExpireSweep {};
            class reconInitClient {};
            class reconRebaseServerTimes {};
        };

        // Player-callable artillery + CAS (Phase 2). Server functions
        // debit bank + spawn shells / dispatch heli; client-local
        // dialogs gather inputs via MapSingleClick.
        class Artillery {
            file = "\overthrow_main\functions\artillery";
            class initArtillery {};
            class initMortar {};
            class registerMortar {};
            class unregisterMortar {};
            class addArtilleryActions {};
            class fireMissionDialog {};
            class fireMissionPickCount {};
            class fireMissionPickTarget {};
            class callFireMission {};
            class casDialog {};
            class casPickTarget {};
            class callCAS {};
            class registerCASHelipad {};
        };

        // Civilian saboteur events + nighttime sabotage (Phase 2).
        // Daytime: high-stab towns spawn an Informant. Nighttime:
        // random NATO base suffers a sabotage effect, revealed to
        // the player as 24h map intel.
        class Civilian {
            file = "\overthrow_main\functions\civilian";
            class civilianEventLoop {};
            class civilianEventTick {};
            class spawnInformant {};
            class civilianEventMarker {};
            class civilianEventMarkerRemove {};
            class civilianEventCleanup {};
            class addInformantAction {};
            class civilianEventTalk {};
            class civilianEventOnConnect {};
            class nighttimeSabotageLoop {};
            class pickAndRunSabotage {};
            class applySabotageEffect {};
            class sabotageMarker {};
        };

        // Multi-nation faction fixups. Per-map initVar.sqf hardcodes
        // BLU_F / BLU_T_F vehicle classes into OT_NATO_Vehicles_Convoy /
        // _GroundSupport / _PoliceSupport and the scalar
        // OT_NATO_Vehicle_Transport_Light. The faction switch in
        // fn_initOverthrow.sqf only reassigns OT_faction_NATO, so when
        // the player picks RHS / CUP / UK3CB the infantry pool swaps
        // but every wheeled support vehicle (LSV, MRAP, Convoy entries)
        // stays vanilla. Most visible symptom: Prowlers accumulating at
        // every NATO FOB after each fn_NATOMissionDeployFOB drop. This
        // function re-mines the vehicle arrays from the active faction's
        // CfgVehicles at OT_fnc_initOverthrow time.
        class Factions {
            file = "\overthrow_main\functions\factions\NATO";
            class factionNATOVehicles {};
            // Second-pass mining. factionNATOVehicles only patches Convoy /
            // GroundSupport / PoliceSupport / Transport_Light. The helpers
            // below cover the rest of the multi-nation residual:
            //   - Statics:           HMG + StaticAA garrison
            //   - Vehicles2:         HVT, Police, Boat, Transport-trucks
            //   - Air:               AirTransport + variants, AirGarrison,
            //                        JetGarrison, ReconDrone, CTRGTransport
            //   - Support:           AirSupport (heavy + small), Tanks, APCs
            //   - GarrisonTemplates: StaticGarrison Level1/2/3 arrays
            //                        (depends on Statics + Vehicles2)
            //   - Police:            5 police unit scalars (graceful-degrade
            //                        via faction infantry when no police role)
            class factionNATOStatics {};
            class factionNATOVehicles2 {};
            class factionNATOAir {};
            class factionNATOSupport {};
            class factionNATOGarrisonTemplates {};
            // factionNATOInfantry mines HAL anti-armor + spec-ops roles
            // (OT_NATO_Unit_AT, _AT_Heavy, _SF) per active faction. Police
            // vars are intentionally NOT touched -- the Apex Gendarmerie
            // (B_Gen_*) is DLC-tied not faction-tied and stays correct
            // regardless of military faction param. factionNATOPolice
            // retained as back-compat shim.
            class factionNATOInfantry {};
            class factionNATOPolice {};
        };

        class Logistics {
            file = "\overthrow_main\functions\logistics";
            class logisticsInit {};
            class logisticsResolveContainer {};
            class logisticsListTagged {};
            class logisticsTravelTime {};
            class logisticsSetRole {};
            class logisticsCreateRoute {};
            class logisticsDeleteRoute {};
            class logisticsPauseRoute {};
            class logisticsDispatchNow {};
            class logisticsDispatch {};
            class logisticsArrive {};
            class logisticsPayloadSummary {};
            class addLogisticsContainerActions {};
        };
    };

    // NATO HAL strategic layer (PLAN_HAL/HAL_BUILD_ORDER.md, MVP + v2).
    // Tag BO_HAL => BO_HAL_fnc_<class>. Server-only at runtime; compiled
    // everywhere so the !isNil hook guards in BO_main resolve.
    class BO_HAL {
        tag = "BO_HAL";

        class HAL {
            file = "\overthrow_main\functions\hal";
            class init {};
            class loadParams {};
            class persist {};
            class aar {};
            class tick {};
            class ingestSighting {};
            class classifyObservedKit {};
            class inferRole {};
            class priorityFromKit {};
            class noteLoss {};
            class heatBump {};
            class heatRecompute {};
            class pickHeatRegion {};
            class tempoRecompute {};
            class provoke {};
            class decayTargets {};
            class packageCatalog {};
            class packageEligible {};
            class pickHotPackage {};
            class rebuildGreenforView {};
            class greenforBranch {};
            class pickLaunchOrigin {};
            class spawnSafely {};
            class spawnGroup {};
            class dressGroup {};
            class launchPackage {};
            class evaluateOp {};
            class estimateWinProb {};
            class breakContact {};
            class retreatCascade {};
            class reinforceVariant {};
            class recycleOp {};
            class watchdog {};
            class fobTouch {};
            class fobWatch {};
            class discoveryEllipse {};
            // Field-command layer: HAL commands all NATO AI.
            class fieldCommand {};
            class taskFieldGroup {};
            class releaseFieldGroup {};
            // Garrison reinforcements (Phase 3 marquee).
            class garrisonTargetNote {};
            class garrisonClearNote {};
            class garrisonReinforce {};
            class garrisonSerialize {};
            class garrisonLiveJoin {};
            // Supply-line interdiction (Phase 3 "cut supply lines").
            class interdictLogistics {};
            // Options-menu runtime master switch.
            class setEnabled {};
            // Zeus admin toolkit dispatcher.
            class halAdminCmd {};
            // Independent aggression dial (Antistasi-style War Level).
            class warLevelBump {};
            // Sanctioned full-send: combined-arms area push (locked #30).
            class launchSurge {};
            // Decapitation target: the HAL Regional Commander.
            class commanderInit {};
            class commanderAppoint {};
            class commanderSpawn {};
            class commanderDespawn {};
            class commanderKilled {};
            // Physical supply line (NATO's only income) + last stand.
            class supplyInit {};
            class supplyRun {};
            class reclaimAssault {};
            // Adaptive counter-doctrine engine.
            class doctrineNote {};
            class doctrineTraits {};
        };

        class HALPackages {
            file = "\overthrow_main\functions\hal\packages";
            class pkg_LGT_INFANTRY {};
            class pkg_LGT_INFANTRY_RURAL {};
            class pkg_MED_SQUAD {};
            class pkg_FORTIFIED_POSITION {};
            class pkg_LIGHT_ARMOR {};
            class pkg_HEAVY_ARMOR {};
            class pkg_AIR_LIGHT {};
            class pkg_RECON_GROUND {};
            class pkg_RECON_AIR {};
            class pkg_CTRG_HUNTER {};
            class pkg_GREENFOR_HIT {};
            class pkg_FACTORY_SABOTAGE {};
            class pkg_INTERDICTION {};
            class pkg_RECON_DRONE {};
            class pkg_AIR_CAS_DRONE {};
            class pkg_AIR_ASSAULT {};
            class pkg_AIR_ATTACK {};
        };
    };
};

// Dialog extensions -- add BO buttons to OT's precompiled dialogs at
// config-merge time. See build_extension.hpp for details.
#include "ui\build_extension.hpp"

// Logistics UI definitions -- BO_dialog_logistics and
// BO_dialog_logisticsRoute. See logistics.hpp for details.
#include "ui\logistics.hpp"

// Persistent garage dialog -- BO_dialog_garage (IDD 8052). See garage.hpp.
#include "ui\garage.hpp"

// New FOB mission classes -- raid SF camp, hit patrol, sabotage
// supply depot. See missions_extension.hpp for details.
#include "missions_extension.hpp"
