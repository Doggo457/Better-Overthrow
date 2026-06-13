#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_LIGHT_ARMOR
 *
 * Wheeled-armor response to a vehicle player: APC plus four dismounts
 * including two AT soldiers who unload 400m off the road. WL >= 4
 * (addendum: AT class is WL-gated, zero telegraph -- the Hunter
 * approaching visibly IS the warning).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _at = missionNamespace getVariable ["OT_NATO_Unit_AT", ""];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
private _classes = [
    missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""],
    _at, _at
];
if (_pool isNotEqualTo []) then { _classes pushBack (selectRandom _pool) };
_classes = _classes select { _x isNotEqualTo "" };

private _apcs = missionNamespace getVariable ["OT_NATO_Vehicles_APC", []];
private _vehCls = if (_apcs isNotEqualTo []) then { selectRandom _apcs } else { "" };

([_origin, _tgt, _classes, _vehCls, "ground", false] call BO_HAL_fnc_spawnGroup)
    params ["_grp", "_veh", "_crew"];

// AT teams dismount further out than line infantry (400m, build doc).
if (!isNull _veh && {!isNull _crew}) then {
    while { count waypoints _crew > 0 } do { deleteWaypoint [_crew, 0] };
    private _dismount = _tgt getPos [400 + random 100, _tgt getDir _origin];
    private _wp = _crew addWaypoint [_dismount, 0];
    _wp setWaypointType "MOVE";
};

[_grp, _veh, _crew]
