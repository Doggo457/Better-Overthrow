#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_heatBump
 *
 * Add heat to the region containing _pos. Regions are keyed by nearest
 * town (OT_regions area markers are optional per map; towns always
 * exist, so they're the robust region proxy).
 *
 * Params: 0: ARRAY pos, 1: NUMBER amount (clamped into 0..1 total)
 */

if (!isServer) exitWith {};
params [["_pos", [0,0,0], [[]]], ["_amt", 0.1, [0]]];

private _town = _pos call OT_fnc_nearestTown;
if (isNil "_town" || {!(_town isEqualType "")} || {_town isEqualTo ""}) exitWith {};

private _idx = BO_HAL_heatCache findIf { (_x select 0) isEqualTo _town };
if (_idx >= 0) then {
    private _e = BO_HAL_heatCache select _idx;
    _e set [1, ((_e select 1) + _amt) min 1];
} else {
    BO_HAL_heatCache pushBack [_town, _amt min 1];
};
