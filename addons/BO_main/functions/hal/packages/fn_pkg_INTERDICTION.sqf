#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_INTERDICTION
 *
 * Supply-line ambush team (PLAN Phase 3 "cut supply lines"): TL + AT +
 * riflemen who park on a road chokepoint along a player logistics
 * route and wait. The target pos handed in by interdictLogistics is
 * already a road point between the route's endpoints.
 *
 * Params: 0: origin, 1: target (road point), 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
private _classes = [missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""]];
private _at = missionNamespace getVariable ["OT_NATO_Unit_AT", ""];
if (_at isNotEqualTo "") then { _classes pushBack _at };
for "_i" from 1 to 3 do { _classes pushBack (selectRandom _pool) };
_classes = _classes select { _x isNotEqualTo "" };

([_origin, _tgt, _classes,
    missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""],
    "ground", false] call BO_HAL_fnc_spawnGroup) params ["_grp", "_veh", "_crew"];

if (!isNull _grp) then {
    // Ambushers hold and stay alert rather than sweep.
    _grp setBehaviour "AWARE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "NORMAL";
    if (missionNamespace getVariable ["BO_HAL_lambsActive", false]) then {
        _grp setVariable ["lambs_danger_cqbRange", 60, false];
    };
};

[_grp, _veh, _crew]
