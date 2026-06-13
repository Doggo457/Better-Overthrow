#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_spawnSafely
 *
 * Resolve the actual ground spawn position at the ORIGIN BASE and a
 * cheap drivability heuristic. RULE (user-locked): NATO spawns at
 * NATO bases only -- the old "dismounted ring around the target"
 * fallback is gone. If the drive looks unpathable, the package still
 * spawns AT the base and walks (the watchdog recovers stuck legs out
 * of player sight; nobody ever materializes in a field).
 *
 * Params: 0: ARRAY origin (base pos), 1: ARRAY target, 2: STRING vehClass
 * Returns: [ARRAY spawnPos, BOOL canDrive]
 */

SERVER_ONLY;
params [["_origin", [0,0,0], [[]]], ["_tgt", [0,0,0], [[]]], ["_vehClass", "", [""]]];

private _canDrive = true;
if (surfaceIsWater _origin) then { _canDrive = false };
if (_canDrive) then {
    private _road = [_origin, 300] call BIS_fnc_nearestRoad;
    if (isNull _road) then {
        // No road net at the origin + long leg = the classic pathfail.
        if ((_origin distance2D _tgt) > 2000) then { _canDrive = false };
    };
};

private _pos = [];
if (_vehClass isNotEqualTo "") then {
    _pos = _origin findEmptyPosition [5, 120, _vehClass];
    if (_pos isEqualTo []) then { _pos = _origin findEmptyPosition [0, 200, _vehClass] };
};
if (_pos isEqualTo []) then { _pos = +_origin };
_pos set [2, 0];

[_pos, _canDrive]
