#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_FORTIFIED_POSITION
 *
 * v2 CQB squad for a player holed up at a fixed position (FOB-adjacent
 * sightings): 8 men, tight cqbRange, deliberate approach.
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _classes = [missionNamespace getVariable ["OT_NATO_Unit_SquadLeader", ""]];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
for "_i" from 1 to 7 do { _classes pushBack (selectRandom _pool) };
_classes = _classes select { _x isNotEqualTo "" };

([_origin, _tgt, _classes,
    missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""],
    "ground", false] call BO_HAL_fnc_spawnGroup) params ["_grp", "_veh", "_crew"];

if (!isNull _grp) then {
    // Counter-doctrine: against a proven CQB fighter the breach team
    // fights tighter (cqbRange 40 = room-to-room posture).
    private _tCqb = (missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]]) param [1, 0];
    _grp setVariable ["lambs_danger_cqbRange", ([120, 40] select (_tCqb >= 0.6)), false];
    _grp setBehaviour "AWARE";
    _grp setSpeedMode "NORMAL";
};

[_grp, _veh, _crew]
