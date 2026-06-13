#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_postInit
 *
 * Server-only bootstrap (audit log, post-load hydrate, pricing init,
 * garbage collector, restricted Zeus curator).
 *
 * Client-only bootstrap:
 *   - ATM ACE Self / Main actions (Banking + Use ATM on shopkeepers)
 *   - Generals = host perms poller
 *
 * No scroll-wheel addActions. All BO player-facing UI is reachable
 * through the Y menu (Loadout Templates, FOB Jobs) or the Options
 * dialog (Audit Log) per the standalone-fork UI consolidation.
 */

if (isServer) then {
    [] spawn {
        waitUntil { sleep 0.5; !isNil "OT_serverInitDone" && {OT_serverInitDone} };

        [] call BO_fnc_initAuditLog;
        [] call BO_fnc_postLoadHydrate;
        [] call BO_fnc_initPricing;
        [] call BO_fnc_initGarbageCollector;
        [] call BO_fnc_initRestrictedZeus;
        [] call BO_fnc_logisticsInit;
        [] call BO_fnc_logMissionDebrisInit;

        // Multi-factory bootstrap:
        //   1. Pick mission params (tick budget + loop interval).
        //   2. Register the pre-baked STARTER factory if it exists
        //      and isn't already in BO_buildFactories (the legacy
        //      single-factory model didn't carry an object identity;
        //      we resolve the nearest OT_factory at OT_factoryPos).
        //      Player-placed factories register themselves via
        //      BO_fnc_initFactory which runs in their build/load
        //      pipeline.
        //   3. Install the per-frame production loop.
        BO_factoryTickBudget = (["bo_factory_tick_budget", 8] call BIS_fnc_getParamValue);
        if (BO_factoryTickBudget < 1) then { BO_factoryTickBudget = 8 };

        BO_factoryLoopInterval = (["bo_factory_loop_interval", 10] call BIS_fnc_getParamValue) * 0.1;
        if (BO_factoryLoopInterval <= 0) then { BO_factoryLoopInterval = 1.0 };

        if (!isNil "OT_factoryPos" && {!isNil "OT_factory"}) then {
            // Only auto-register the starter if the player has bought it
            // ("Factory" in GEURowned). Pre-purchase the building exists
            // on the map but isn't owned by the resistance, matching the
            // legacy single-factory gating (GUERLoop's old factory tick
            // also gated on "Factory" in GEURowned).
            private _owned = server getVariable ["GEURowned", []];
            private _starter = OT_factoryPos nearestObject OT_factory;
            if (("Factory" in _owned) && {!isNull _starter} && {(_starter distance OT_factoryPos) < 50}) then {
                private _registry = server getVariable ["BO_buildFactories", []];
                if !(_starter in _registry) then {
                    // Restore from save snapshot if loadGame stashed
                    // one (starter is map-baked so it can't ride the
                    // slot-10 per-object save path). Otherwise seed
                    // defaults.
                    private _snap = server getVariable ["BO_starterFactoryState", []];
                    if (_snap isNotEqualTo []) then {
                        _snap params [
                            ["_sQueue", [], [[]]],
                            ["_sProducing", "", [""]],
                            ["_sProducetime", 0, [0]],
                            ["_sEnabled", true, [false]],
                            ["_sName", "", [""]]
                        ];
                        _starter setVariable ["BO_queue", _sQueue, true];
                        _starter setVariable ["BO_producing", _sProducing, true];
                        _starter setVariable ["BO_producetime", _sProducetime, true];
                        _starter setVariable ["BO_factoryEnabled", _sEnabled, true];
                        _starter setVariable ["BO_factoryName", _sName, true];
                        ["INFO", "factory", format ["Starter factory state restored: queue=%1, producing=%2", count _sQueue, _sProducing]] call BO_fnc_log;
                    } else {
                        if (isNil { _starter getVariable "BO_queue" })          then { _starter setVariable ["BO_queue", [], true] };
                        if (isNil { _starter getVariable "BO_producing" })      then { _starter setVariable ["BO_producing", "", true] };
                        if (isNil { _starter getVariable "BO_producetime" })    then { _starter setVariable ["BO_producetime", 0, true] };
                        if (isNil { _starter getVariable "BO_factoryEnabled" }) then { _starter setVariable ["BO_factoryEnabled", true, true] };
                        if (isNil { _starter getVariable "BO_factoryName" })    then { _starter setVariable ["BO_factoryName", "", true] };
                    };

                    [_starter] call BO_fnc_registerFactory;
                };
            };
        };

        [] call BO_fnc_factoryLoop;

        // Production businesses (Lumberyard, Mine, Vineyard, Winery,
        // Olive Plantation, Chemical Plant). Same chunked round-robin
        // model as factories. Player-placed businesses register
        // themselves via BO_fnc_initBusiness in their build/load path;
        // here we only pick the mission params and install the loop.
        BO_businessTickBudget = (["bo_business_tick_budget", 8] call BIS_fnc_getParamValue);
        if (BO_businessTickBudget < 1) then { BO_businessTickBudget = 8 };

        BO_businessLoopInterval = (["bo_business_loop_interval", 100] call BIS_fnc_getParamValue) * 0.1;
        if (BO_businessLoopInterval <= 0) then { BO_businessLoopInterval = 10.0 };

        [] call BO_fnc_businessLoop;

        // -- Phase 2 init blocks --

        // Persistent garage / vehicle insurance.
        [] call BO_fnc_postLoadHydrateGarage;

        // Recon flights / paid intel.
        BO_reconDurationMinutes = ["bo_recon_duration_min", 10] call BIS_fnc_getParamValue;
        if (BO_reconDurationMinutes <= 0) then { BO_reconDurationMinutes = 10 };
        BO_reconCostTown    = ["bo_recon_cost_town",    500]  call BIS_fnc_getParamValue;
        BO_reconCostRegion  = ["bo_recon_cost_region",  2000] call BIS_fnc_getParamValue;
        BO_reconCostMap     = ["bo_recon_cost_map",     8000] call BIS_fnc_getParamValue;
        BO_reconStandingMin = ["bo_recon_standing_min", 50]   call BIS_fnc_getParamValue;
        BO_reconNATOResourceTick = ["bo_recon_nato_tick", 50] call BIS_fnc_getParamValue;
        publicVariable "BO_reconDurationMinutes";
        publicVariable "BO_reconCostTown";
        publicVariable "BO_reconCostRegion";
        publicVariable "BO_reconCostMap";
        publicVariable "BO_reconStandingMin";
        publicVariable "BO_reconNATOResourceTick";
        [] call BO_fnc_reconExpireSweep;

        // Player-callable artillery + CAS. One-shot init (no PFH).
        [] call BO_fnc_initArtillery;

        // Civilian saboteur events + nighttime sabotage (Phase 2).
        BO_civilianEventsEnabled = (["bo_civilian_events_enabled", 1] call BIS_fnc_getParamValue) isEqualTo 1;
        BO_nighttimeSabotageEnabled = (["bo_nighttime_sabotage_enabled", 1] call BIS_fnc_getParamValue) isEqualTo 1;
        BO_nighttimeSabotageFrequency = ["bo_nighttime_sabotage_frequency", 1] call BIS_fnc_getParamValue;
        BO_civilianEventsPerTickMax = ["bo_civilian_events_per_tick_max", 2] call BIS_fnc_getParamValue;
        BO_civilianEventLifetime = ["bo_civilian_event_lifetime", 20] call BIS_fnc_getParamValue;
        BO_civilianEventRewardCash = ["bo_civilian_event_reward_cash", 250] call BIS_fnc_getParamValue;
        BO_sabotageSupplyDrain = ["bo_sabotage_supply_drain", 50] call BIS_fnc_getParamValue;
        server setVariable ["BO_activeCivilianEvents", [], true];
        [] call BO_fnc_civilianEventLoop;
        [] call BO_fnc_nighttimeSabotageLoop;
        // Re-deliver civilian event state to JIP players (server-side).
        if (isNil "BO_civilianEventJIPEH") then {
            BO_civilianEventJIPEH = addMissionEventHandler ["PlayerConnected", {
                params ["_id", "_uid", "_name", "_jip", "_owner"];
                [_id, _uid, _name, _jip, _owner] call BO_fnc_civilianEventOnConnect;
            }];
        };

        // World demand events. Cache mission params on missionNamespace.
        missionNamespace setVariable ["bo_events_enabled_cached",
            (["bo_events_enabled", 1] call BIS_fnc_getParamValue) isEqualTo 1];
        missionNamespace setVariable ["bo_events_per_day_cached",
            ["bo_events_per_day", 3] call BIS_fnc_getParamValue];
        missionNamespace setVariable ["bo_event_duration_days_cached",
            ["bo_event_duration_days", 2] call BIS_fnc_getParamValue];
        missionNamespace setVariable ["bo_event_multiplier_max_cached",
            ["bo_event_multiplier_max", 200] call BIS_fnc_getParamValue];
        if (missionNamespace getVariable ["bo_events_enabled_cached", true]) then {
            [] call BO_fnc_worldEventsInit;
        };

        // NATO Police Stations -- one per NATO-controlled town.
        // Idempotent on a reload (BO_natoPoliceStations rides the
        // standard server-var save loop and skip-dedupes).
        [] call BO_fnc_initNATOPoliceStations;

        // NATO HAL strategic layer (Phase 3). Runs LAST: it reads the
        // OT_NATO_* faction surface, the postLoadHydrate-reset
        // BO_HAL_silentTicks (locked D3) and the registered bases.
        [] call BO_HAL_fnc_init;

        ["INFO", "init", "Better Overthrow server postInit complete"] call BO_fnc_log;
        [AUDIT_ADMIN, "Better Overthrow systems online", nil, "", ""] call BO_fnc_auditServer;
    };
};

if (hasInterface) then {
    [] call BO_fnc_addATMActions;
    [] call BO_fnc_addLogisticsContainerActions;

    // Phase 2 client-side action installers.
    [] call BO_fnc_garageInstallActions;
    [] call BO_fnc_reconInitClient;
    [] call BO_fnc_addArtilleryActions;
    [] call BO_fnc_addInformantAction;

    // Generals get host-level perms: OT_adminMode flag controls
    // fast-travel limits, vehicle-purchase gates, debug helpers and a
    // few notification verbosity branches. Generals are players the
    // server has put in `server var "generals"` -- on a local host
    // that's whoever ran New Game; on a dedicated server the existing
    // General(s) can promote others via fn_makeGeneral.
    //
    // We re-check periodically so promotions/demotions take effect
    // within ~30s without requiring a reconnect.
    [] spawn {
        waitUntil { sleep 1; !isNull player && {!isNil "OT_varInitDone"} && {OT_varInitDone} };
        private _wasGeneral = false;
        while { !isNull player } do {
            private _isGeneral = call OT_fnc_playerIsGeneral;
            if (_isGeneral && !_wasGeneral) then {
                OT_adminMode = true;
                BO_LOG_INFO("admin","Granted admin mode (player is a General)");
                if (_wasGeneral isNotEqualTo false || {time > 30}) then {
                    "You are now a General -- admin mode granted" call OT_fnc_notifyMinor;
                };
            };
            if (!_isGeneral && _wasGeneral && !(call BIS_fnc_admin isEqualTo 2)) then {
                OT_adminMode = false;
                "You are no longer a General -- admin mode revoked" call OT_fnc_notifyMinor;
            };
            _wasGeneral = _isGeneral;
            sleep 30;
        };
    };

};

["INFO", "init", "Better Overthrow postInit dispatched"] call BO_fnc_log;
