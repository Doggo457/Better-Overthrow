#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_aar
 *
 * After-action ring buffer (V10): in-memory ring of the last 100 HAL
 * events plus an RPT line per event. Locked decision #7: server-side,
 * diag_log first; no UI panel unless debugging demands one.
 *
 * Params: 0: STRING event, 1: ARRAY data
 */

if (!isServer) exitWith {};
params [["_evt", "", [""]], ["_data", [], [[]]]];

BO_HAL_aarRing pushBack [serverTime, _evt, _data];
if (count BO_HAL_aarRing > 100) then { BO_HAL_aarRing deleteAt 0 };

diag_log format ["[BO][HAL][AAR] t=%1 %2 %3", round serverTime, _evt, _data];
