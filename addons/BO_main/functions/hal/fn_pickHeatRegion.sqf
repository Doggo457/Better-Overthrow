#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pickHeatRegion
 *
 * Highest-heat region for the cold/recon branch.
 * Returns [townName, pos, heat] or [] when the map is cold.
 */

SERVER_ONLY;

if (BO_HAL_heatCache isEqualTo []) exitWith { [] };

private _best = ["", -1];
{
    if ((_x select 1) > (_best select 1)) then { _best = _x };
} forEach BO_HAL_heatCache;

if ((_best select 1) < 0.05) exitWith { [] };

private _pos = server getVariable [(_best select 0), []];
if (_pos isEqualTo []) exitWith { [] };

[_best select 0, _pos, _best select 1]
