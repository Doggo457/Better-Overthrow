#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_HEAVY_ARMOR
 *
 * v2 MBT response: tank plus APC with Titan-class AT_Heavy dismounts.
 * WL >= 5. The 4km engine note at altitude is the telegraph (addendum
 * no-notifications rule -- the world IS the warning).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh(tank), crewGrp(tank)] -- the APC rides in data-free
 * convoy behind the tank's crew group.
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _atH = missionNamespace getVariable ["OT_NATO_Unit_AT_Heavy", ""];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
private _classes = [
    missionNamespace getVariable ["OT_NATO_Unit_SquadLeader", ""],
    _atH, _atH
];
if (_pool isNotEqualTo []) then {
    _classes pushBack (selectRandom _pool);
    _classes pushBack (selectRandom _pool);
};
_classes = _classes select { _x isNotEqualTo "" };

private _apcs = missionNamespace getVariable ["OT_NATO_Vehicles_APC", []];
private _apcCls = if (_apcs isNotEqualTo []) then { selectRandom _apcs } else { "" };

// Dismounts ride the APC.
([_origin, _tgt, _classes, _apcCls, "ground", false] call BO_HAL_fnc_spawnGroup)
    params ["_grp", "_apc", "_apcCrew"];
if (isNull _grp) exitWith { [grpNull, objNull, grpNull] };

// The tank leads the column.
private _tanks = missionNamespace getVariable ["OT_NATO_Vehicles_TankSupport", []];
private _tank = objNull;
private _tankCrew = grpNull;
if (_tanks isNotEqualTo []) then {
    private _tcls = selectRandom _tanks;
    private _sp = (getPosATL _apc) findEmptyPosition [10, 120, _tcls];
    if (_sp isEqualTo []) then { _sp = (getPosATL _apc) getPos [25, random 360] };
    _tank = createVehicle [_tcls, [0, 0, 1500 + random 300], [], 0, "CAN_COLLIDE"];
    _tank setDir ((getPosATL _apc) getDir _tgt);
    _tank setPosATL _sp;
    _tank allowCrewInImmobile false;
    _tank setVariable ["BO_HAL_unit", true, false];
    createVehicleCrew _tank;
    _tankCrew = group (effectiveCommander _tank);
    if (isNull _tankCrew && {!isNull driver _tank}) then { _tankCrew = group (driver _tank) };
    if (!isNull _tankCrew) then {
        [_tankCrew, false] call BO_HAL_fnc_dressGroup;
        // Sentinel op tag: not tracked in the op record, but the
        // field-command pass must never adopt the tank as a stray.
        _tankCrew setVariable ["BO_HAL_op", -1, false];
        _tankCrew setBehaviour "AWARE";
        private _wp = _tankCrew addWaypoint [_tgt getPos [350, _tgt getDir _origin], 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
    };
};

// Track the tank as the op vehicle (heaviest asset); the APC crew
// group is the tracked crew so dismount logic still fires.
private _veh = if (!isNull _tank) then { _tank } else { _apc };
[_grp, _veh, _apcCrew]
