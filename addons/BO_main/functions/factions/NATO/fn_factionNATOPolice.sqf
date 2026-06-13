#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOPolice (DEPRECATED back-compat shim)
 *
 * Superseded by BO_fnc_factionNATOInfantry, which covers the five police
 * scalars AND the three HAL Day-1 vars (OT_NATO_Unit_AT, _AT_Heavy, _SF)
 * in a single CfgVehicles sweep. Kept here only in case external code
 * calls BO_fnc_factionNATOPolice by name (Zen hooks, debug console).
 * fn_initOverthrow no longer calls this; it calls factionNATOInfantry
 * directly.
 */

if (!isServer) exitWith {};

BO_LOG_DEBUG("factions", "factionNATOPolice: shim -> factionNATOInfantry");
[] call BO_fnc_factionNATOInfantry;
