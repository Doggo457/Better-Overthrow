#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_GREENFOR_HIT
 *
 * Delegated package: hands the strike to OT's own counter-attack
 * machinery (OT_fnc_NATOCounterTown), which owns its broadcasts and
 * spawning. HAL pays the cost and walks away -- returning nulls tells
 * launchPackage this is a fire-and-forget delegation.
 *
 * Target town comes via BO_HAL_greenforTown (set by greenforBranch);
 * falls back to nearest town to the target pos.
 *
 * Params: 0: origin, 1: target pos, 2: catalog entry
 * Returns: [grpNull, objNull, grpNull]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _town = missionNamespace getVariable ["BO_HAL_greenforTown", ""];
missionNamespace setVariable ["BO_HAL_greenforTown", nil];
if (_town isEqualTo "") then {
    _town = _tgt call OT_fnc_nearestTown;
};

if (!isNil "_town" && {_town isEqualType ""} && {_town isNotEqualTo ""}) then {
    [_town, 200] spawn OT_fnc_NATOCounterTown;
    ["greenfor_countertown", [_town]] call BO_HAL_fnc_aar;
};

[grpNull, objNull, grpNull]
