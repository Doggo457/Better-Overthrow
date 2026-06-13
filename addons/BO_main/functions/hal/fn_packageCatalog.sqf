#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_packageCatalog
 *
 * Central package table. Locked decisions #16/#17: every package
 * declares the OT_NATO_* vars it derives classes from; builders never
 * hardcode faction classnames. Addendum: AT-class packages WL>=4,
 * AA-class WL>=6, zero notifications (no telegraph fields).
 *
 * Entry: [id, cost, wlMin, requiredVars, builderFnName]
 * Returns: ARRAY of entries (built once, cached).
 */

if (!isNil "BO_HAL_packageCache") exitWith { BO_HAL_packageCache };

BO_HAL_packageCache = [
    // ---- hot (threat-matched) ----
    ["LGT_INFANTRY",       60, 0, ["OT_NATO_Unit_TeamLeader", "OT_NATO_Vehicle_Transport_Light"], "BO_HAL_fnc_pkg_LGT_INFANTRY"],
    ["LGT_INFANTRY_RURAL", 90, 0, ["OT_NATO_Unit_Sniper", "OT_NATO_Unit_Spotter", "OT_NATO_Vehicle_Transport_Light"], "BO_HAL_fnc_pkg_LGT_INFANTRY_RURAL"],
    ["MED_SQUAD",         180, 0, ["OT_NATO_Unit_SquadLeader", "OT_NATO_Vehicles_GroundSupport"], "BO_HAL_fnc_pkg_MED_SQUAD"],
    ["FORTIFIED_POSITION",200, 0, ["OT_NATO_Unit_SquadLeader", "OT_NATO_Vehicle_Transport_Light"], "BO_HAL_fnc_pkg_FORTIFIED_POSITION"],
    ["LIGHT_ARMOR",       220, 4, ["OT_NATO_Vehicles_APC", "OT_NATO_Unit_AT"], "BO_HAL_fnc_pkg_LIGHT_ARMOR"],
    ["HEAVY_ARMOR",       450, 5, ["OT_NATO_Vehicles_TankSupport", "OT_NATO_Vehicles_APC", "OT_NATO_Unit_AT_Heavy"], "BO_HAL_fnc_pkg_HEAVY_ARMOR"],
    ["AIR_CAS_DRONE",     260, 4, ["OT_NATO_Vehicles_CASDrone"], "BO_HAL_fnc_pkg_AIR_CAS_DRONE"],
    ["AIR_ASSAULT",       320, 5, ["OT_NATO_Unit_SquadLeader", "OT_NATO_Vehicle_AirTransport_Small"], "BO_HAL_fnc_pkg_AIR_ASSAULT"],
    ["AIR_LIGHT",         380, 6, ["OT_NATO_Vehicles_AirSupport_Small"], "BO_HAL_fnc_pkg_AIR_LIGHT"],
    ["AIR_ATTACK",        420, 6, ["OT_NATO_Vehicles_AirSupport"], "BO_HAL_fnc_pkg_AIR_ATTACK"],
    // ---- cold (discovery) ----
    ["RECON_DRONE",        40, 2, ["OT_NATO_Vehicles_ReconDrone"], "BO_HAL_fnc_pkg_RECON_DRONE"],
    ["RECON_GROUND",       50, 0, ["OT_NATO_Unit_Sniper", "OT_NATO_Unit_Spotter"], "BO_HAL_fnc_pkg_RECON_GROUND"],
    ["RECON_AIR",          90, 0, ["OT_NATO_Vehicle_AirTransport_Small"], "BO_HAL_fnc_pkg_RECON_AIR"],
    ["CTRG_HUNTER",       280, 6, ["OT_NATO_Unit_SF", "OT_NATO_Vehicle_AirTransport_Small"], "BO_HAL_fnc_pkg_CTRG_HUNTER"],
    // ---- greenfor (economy) ----
    ["GREENFOR_HIT",      110, 0, [], "BO_HAL_fnc_pkg_GREENFOR_HIT"],
    ["FACTORY_SABOTAGE",  160, 0, ["OT_NATO_Unit_TeamLeader"], "BO_HAL_fnc_pkg_FACTORY_SABOTAGE"],
    ["INTERDICTION",      140, 4, ["OT_NATO_Unit_TeamLeader", "OT_NATO_Vehicle_Transport_Light"], "BO_HAL_fnc_pkg_INTERDICTION"]
];

BO_HAL_packageCache
