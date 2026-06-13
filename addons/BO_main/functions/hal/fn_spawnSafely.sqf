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
// Cross-call deconfliction. findEmptyPosition can't see vehicles still
// falling in from altitude (createVehicle spawns them at z~1000), so two
// ops launched the same tick -- or a surge of packages from one base --
// resolve to the same slot and detonate on top of each other. Keep a
// short-lived ledger of recently-claimed slots and reject candidates that
// land too close to one.
private _used = (missionNamespace getVariable ["BO_HAL_recentSpawnSlots", []]) select { (serverTime - (_x select 1)) < 30 };
private _sep = if (_vehClass isNotEqualTo "") then { 18 } else { 8 };

for "_attempt" from 0 to 8 do {
    private _cand = if (_vehClass isNotEqualTo "") then {
        _origin findEmptyPosition [8 + _attempt * _sep, 140 + _attempt * 25, _vehClass]
    } else {
        _origin findEmptyPosition [4 + _attempt * _sep, 120]
    };
    if (_cand isEqualTo []) then { _cand = _origin getPos [(14 + _attempt * (_sep + 6)), (_attempt * 47) mod 360] };
    _cand set [2, 0];
    if ((_used findIf { ((_x select 0) distance2D _cand) < (_sep + 4) }) isEqualTo -1) exitWith { _pos = _cand };
};
if (_pos isEqualTo []) then { _pos = _origin getPos [18 + random 20, random 360]; _pos set [2, 0] };

_used pushBack [_pos, serverTime];
missionNamespace setVariable ["BO_HAL_recentSpawnSlots", _used];

[_pos, _canDrive]
