#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryVehicleSpawnPos
 *
 * Compute the vehicle-output spawn position + dir for a given
 * factory object. Returns [pos, dir]. Used by the production tick
 * when the output classname is a vehicle.
 *
 * Per-factory model: each placed factory has its own spawn point
 * computed from its actual position + dir (20m out, facing reversed),
 * matching the original single-factory offset semantics from
 * fn_initFactory.
 *
 * Starter-factory legacy: if _factory's getDir is approximately the
 * same as the pre-baked map building (i.e. this IS the starter site),
 * we honour the map's OT_factoryVehicleSpawn / OT_factoryVehicleDir
 * if they were customised by the map data so the spawn point
 * doesn't drift.
 *
 * Params:
 *   0: OBJECT - factory
 *
 * Returns: [_pos, _dir] - pos array-3, dir scalar.
 */

params [["_factory", objNull, [objNull]]];
if (isNull _factory) exitWith { [[0,0,0], 0] };

private _useStarter = false;
if (!isNil "OT_factoryPos") then {
    // If this factory is at the starter coordinates, prefer the
    // map-baked spawn point (which the data/economy.sqf may have
    // tuned for the specific terrain).
    if ((getPosATL _factory) distance OT_factoryPos < 5) then {
        _useStarter = true;
    };
};

if (_useStarter && {!isNil "OT_factoryVehicleSpawn"} && {!isNil "OT_factoryVehicleDir"}) exitWith {
    [OT_factoryVehicleSpawn, OT_factoryVehicleDir]
};

private _pos = _factory getPos [20, getDir _factory];
private _dir = (getDir _factory + 180) mod 360;
[_pos, _dir]
