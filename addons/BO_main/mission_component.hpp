/* Included at top of mission's description.ext for default Overthrow settings
 * #include "\overthrow_main\mission_component.hpp"
 *
 * Override values after if required
 */
#include "\overthrow_main\script_component.hpp"

author = QUOTE(MOD_AUTHOR);
OnLoadMission = QUOTE(VERSION_STR - Read the wiki at overthrow.fandom.com for more information);

onLoadMissionTime = 1;
allowSubordinatesTakeWeapons = 1;

joinUnassigned = 1;
briefing = 0;

class Header {
    gameType = "Coop";
    minPlayers = 1;
    maxPlayers = 32;
};

allowFunctionsLog = 0;
enableDebugConsole = 1;

respawn = "BASE";
respawnDelay = 5;
respawnVehicleDelay = 120;
respawnDialog = 0;
aiKills = 0;
disabledAI = 1;
saving = 0;
showCompass = 1;
showRadio = 1;
showGPS = 1;
showMap = 1;
showBinocular = 1;
showNotepad = 1;
showWatch = 1;
debriefing = 0;
allowProfileGlasses = 0;

//Disable ACE blood (just too much of it in a heavy game)
class Params {
    class ot_enemy_faction {
        title = "Occupying faction";
        texts[] = {
            "0. Map default",
            "1. Vanilla NATO",
            "2. Vanilla NATO pacific",
            "3. Vanilla NATO woodland",
            "4. RHS US Army Woodland",
            "5. RHS US Army Desert",
            "6. RHS USMC Woodland",
            "7. RHS USMC Desert",
            "8. RHS Horizon Islands Defence Force",
            "9. 3CB AAF",
            "10. 3CB Livonian Defence Force",
            "11. 3CB Livonia Separatist Militia",
            "12. 3CB Malden Defence Force",
            "13. 3CB Middle East Insurgents"
        };
        values[] = {
            0, // Map default
            1, // Vanilla NATO
            2, // Vanilla NATO pacific
            3, // Vanilla NATO woodland
            4, // RHS US Army Woodland
            5, // RHS US Army Desert
            6, // RHS USMC Woodland
            7, // RHS USMC Desert
            8, // RHS Horizon Islands Defence Force
            9, // 3CB AAF
            10, // 3CB Livonian Defence Force
            11, // 3CB Livonia Separatist Militia
            12, // 3CB Malden Defence Force
            13 // 3CB Middle East Insurgents
        };
        default = 0;
    };
    class ot_start_autoload {
        title = "Autoload a save or start a new game";
        values[] = {0, 1};
        texts[] = {"No", "Yes"};
        default = 0;
    };
    class ot_start_difficulty {
        title = "Game difficulty (Only with autoload)";
        values[] = {0, 1, 2};
        texts[] = {"Easy", "Normal", "Hard"};
        default = 1;
    };
    class ot_start_fasttravel {
        title = "Fast Travel (Only with autoload)";
        values[] = {0, 1, 2};
        texts[] = {"Free", "Costs", "Disabled"};
        default = 1;
    };
    class ot_start_fasttravelrules {
        title = "Fast Travel Rules (Only with autoload)";
        values[] = {0, 1, 2};
        texts[] = {"Open", "No Weapons", "Restricted"};
        default = 1;
    };
    class ot_showplayermarkers {
        title = "Show Player Markers on HUD";
        values[] = {1, 0};
        texts[] = {"Yes", "No"};
        default = 1;
    };
    class ot_showenemygroup {
        title = "Show known enemy groups on map";
        values[] = {1, 0};
        texts[] = {"Yes", "No"};
        default = 1;
    };
    class ot_randomizeloadouts {
        title = "Randomize NATO loadouts";
        values[] = {1, 0};
        texts[] = {"Yes", "No"};
        default = 0;
    };
    class ot_gangmembercap {
        title = "Gang Maximum Size";
        texts[] = {"10", "15", "20", "25", "30"};
        values[] = {10, 15, 20, 25, 30};
        default = 15;
    };
    class ot_gangresourcecap {
        title = "Gang Maximum Resources";
        texts[] = {"Low", "Medium", "High", "Very High"};
        values[] = {300, 600, 900, 1500};
        default = 600;
    };
    class ot_factoryproductionmulti {
        title = "Factory Production Multiplier";
        texts[] = {"100% Speed", "150% Speed", "200% Speed", "250% Speed", "300% Speed", "350% Speed", "400% Speed", "450% Speed", "500% Speed", "1000% Speed"};
        values[] = {100, 150, 200, 250, 300, 350, 400, 450, 500, 1000};
        default = 100;
    };
    // BO multi-factory: how many factories to tick per PFH iteration.
    // Bigger = more concurrent throughput but more server work each
    // call; smaller = smoother frame impact at the cost of slower
    // round-trip when N factories is large.
    class bo_factory_tick_budget {
        title = "Factory Tick Budget (per second)";
        texts[] = {"4 factories", "8 factories", "16 factories", "32 factories"};
        values[] = {4, 8, 16, 32};
        default = 8;
    };
    // BO multi-factory: real-time seconds between PFH iterations.
    // Stored as deciseconds (param values are integers); divided by
    // 10 at consumption time in fn_postInit. At 1.0s with 60s game
    // minutes, every factory ticks at least once per game-minute.
    class bo_factory_loop_interval {
        title = "Factory Loop Interval";
        texts[] = {"0.5s", "1.0s", "2.0s", "5.0s"};
        values[] = {5, 10, 20, 50};
        default = 10;
    };
    // BO production businesses (Lumberyard / Mine / Vineyard / Winery
    // / Olive Plantation / Chemical Plant): how many businesses to
    // tick per PFH iteration. Same trade-off as factory budget.
    class bo_business_tick_budget {
        title = "Business Tick Budget (per cycle)";
        texts[] = {"4 businesses", "8 businesses", "16 businesses", "32 businesses"};
        values[] = {4, 8, 16, 32};
        default = 8;
    };
    // BO production businesses: real-time seconds between PFH
    // iterations. Stored as deciseconds; divided by 10 at consumption
    // in fn_postInit. Businesses tick once per in-game hour, so the
    // loop just needs to cover the registry before the hour rolls
    // over (3600s real time at 4x time compression = 900s real time).
    class bo_business_loop_interval {
        title = "Business Loop Interval";
        texts[] = {"5s", "10s", "30s", "60s"};
        values[] = {50, 100, 300, 600};
        default = 100;
    };
    // BO persistent garage + vehicle insurance (Phase 2).
    class bo_garage_slots_per_warehouse {
        title = "Garage slots per owned warehouse";
        texts[] = {"3", "5", "8", "12", "20"};
        values[] = {3, 5, 8, 12, 20};
        default = 5;
    };
    class bo_garage_store_fee_pct {
        title = "Garage store fee (% of vehicle value)";
        texts[] = {"0%", "2%", "5%", "10%", "15%"};
        values[] = {0, 2, 5, 10, 15};
        default = 5;
    };
    class bo_garage_retrieve_fee_pct {
        title = "Garage retrieval fee (% of vehicle value)";
        texts[] = {"0%", "2%", "3%", "5%", "10%"};
        values[] = {0, 2, 3, 5, 10};
        default = 3;
    };
    class bo_garage_insurance_premium_pct {
        title = "Insurance premium (% of vehicle value)";
        texts[] = {"5%", "10%", "15%", "25%", "40%"};
        values[] = {5, 10, 15, 25, 40};
        default = 15;
    };
    class bo_garage_insurance_payout_pct {
        title = "Insurance payout (% of vehicle value at policy)";
        texts[] = {"30%", "50%", "60%", "75%", "90%"};
        values[] = {30, 50, 60, 75, 90};
        default = 60;
    };
    class bo_garage_insurance_refund_pct {
        title = "Insurance cancellation refund (% of premium)";
        texts[] = {"0%", "25%", "40%", "60%", "80%"};
        values[] = {0, 25, 40, 60, 80};
        default = 40;
    };
    class bo_garage_auto_radius {
        title = "Captured-vehicle ACE action radius (m)";
        texts[] = {"50m", "75m", "100m", "150m", "250m"};
        values[] = {50, 75, 100, 150, 250};
        default = 75;
    };
    class bo_garage_generals_exempt {
        title = "Generals exempt from garage capacity";
        texts[] = {"No", "Yes"};
        values[] = {0, 1};
        default = 1;
    };
    // BO recon flights / paid intel (Phase 2).
    class bo_recon_duration_min {
        title = "Recon Flight Duration (in-game min)";
        texts[] = {"5", "10", "15", "20", "30"};
        values[] = {5, 10, 15, 20, 30};
        default = 10;
    };
    class bo_recon_cost_town {
        title = "Recon Cost: Town tier";
        texts[] = {"$250", "$500", "$1000", "$1500"};
        values[] = {250, 500, 1000, 1500};
        default = 500;
    };
    class bo_recon_cost_region {
        title = "Recon Cost: Region tier";
        texts[] = {"$1000", "$2000", "$4000", "$6000"};
        values[] = {1000, 2000, 4000, 6000};
        default = 2000;
    };
    class bo_recon_cost_map {
        title = "Recon Cost: Map-wide tier";
        texts[] = {"$4000", "$8000", "$12000", "$20000"};
        values[] = {4000, 8000, 12000, 20000};
        default = 8000;
    };
    class bo_recon_standing_min {
        title = "Recon: Standing required";
        texts[] = {"0", "25", "50", "75", "100"};
        values[] = {0, 25, 50, 75, 100};
        default = 50;
    };
    class bo_recon_nato_tick {
        title = "Recon: NATO resource tick";
        texts[] = {"+0", "+25", "+50", "+100"};
        values[] = {0, 25, 50, 100};
        default = 50;
    };
    // BO player-callable artillery + CAS (Phase 2).
    class bo_artillery_cooldown_min {
        title = "Artillery Cooldown (per mortar)";
        texts[] = {"3 minutes", "5 minutes", "10 minutes", "30 minutes"};
        values[] = {3, 5, 10, 30};
        default = 5;
    };
    class bo_artillery_civilian_penalty {
        title = "Civilian Collateral Penalty (per kill)";
        texts[] = {"-1", "-3", "-5", "-10"};
        values[] = {-1, -3, -5, -10};
        default = -5;
    };
    class bo_cas_cooldown_min {
        title = "CAS Cooldown (per helipad)";
        texts[] = {"10 minutes", "20 minutes", "30 minutes", "60 minutes"};
        values[] = {10, 20, 30, 60};
        default = 20;
    };
    // BO Phase 2: civilian saboteur events.
    class bo_civilian_events_enabled {
        title = "Civilian Saboteur Events";
        values[] = {1, 0};
        texts[] = {"Enabled", "Disabled"};
        default = 1;
    };
    class bo_civilian_events_per_tick_max {
        title = "Max Informants per Cycle";
        values[] = {1, 2, 3};
        texts[] = {"1", "2", "3"};
        default = 2;
    };
    class bo_civilian_event_lifetime {
        title = "Informant Lifetime (in-game minutes)";
        values[] = {10, 20, 30, 45};
        texts[] = {"10 min", "20 min", "30 min", "45 min"};
        default = 20;
    };
    class bo_civilian_event_reward_cash {
        title = "Informant Base Reward ($)";
        values[] = {100, 250, 500, 1000};
        texts[] = {"$100", "$250", "$500", "$1000"};
        default = 250;
    };
    class bo_nighttime_sabotage_enabled {
        title = "Nighttime Sabotage";
        values[] = {1, 0};
        texts[] = {"Enabled", "Disabled"};
        default = 1;
    };
    class bo_nighttime_sabotage_frequency {
        title = "Nighttime Sabotage Frequency";
        values[] = {0, 1, 2};
        texts[] = {"Off", "Once per night", "Multiple per night"};
        default = 1;
    };
    class bo_sabotage_supply_drain {
        title = "Sabotage Supply Theft Drain";
        values[] = {25, 50, 100, 200};
        texts[] = {"-25", "-50", "-100", "-200"};
        default = 50;
    };
    // BO World Demand Events (Phase 2).
    class bo_events_enabled {
        title = "World Demand Events";
        values[] = {0, 1};
        texts[] = {"Disabled", "Enabled"};
        default = 1;
    };
    class bo_events_per_day {
        title = "Demand Events Per Day";
        values[] = {1, 3, 5, 7};
        texts[] = {"1", "3", "5", "7"};
        default = 3;
    };
    class bo_event_duration_days {
        title = "Demand Event Duration";
        values[] = {1, 2, 3, 5};
        texts[] = {"1 day", "2 days", "3 days", "5 days"};
        default = 2;
    };
    class bo_event_multiplier_max {
        title = "Demand Event Max Multiplier";
        values[] = {150, 200, 300, 500};
        texts[] = {"1.5x", "2x", "3x", "5x"};
        default = 200;
    };
    class ace_medical_level {
        title = "ACE Medical Level";
        ACE_setting = 1;
        values[] = {1, 2};
        texts[] = {"Basic", "Advanced"};
        default = 1;
    };
    class ace_medical_blood_enabledFor {
        title = "ACE Blood";
        ACE_setting = 1;
        values[] = {0, 1, 2};
        texts[] = {"None", "Players Only", "All"};
        default = 1;
    };
};

// ZEN integration
// This will do nothing if ZEN is loaded
class zen_context_menu_actions {
    class ot_setmoney {
        displayName = "Overthrow: Set Money";
        icon = "\overthrow_main\ui\markers\shop-General.paa";
        statement = "[_hoveredEntity] call OT_fnc_zenSetMoney";
        condition = "_hoveredEntity isKindOf 'CAManBase' && { isPlayer _hoveredEntity }";
        priority = 50;
    };
};
