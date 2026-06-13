#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_heatRecompute
 *
 * Per-tick heat decay: x0.85 per tick, entries below 0.02 dropped.
 * Sightings/losses bump heat between ticks (fn_heatBump).
 */

SERVER_ONLY;

{
    _x set [1, (_x select 1) * 0.85];
} forEach BO_HAL_heatCache;

BO_HAL_heatCache = BO_HAL_heatCache select { (_x select 1) >= 0.02 };
