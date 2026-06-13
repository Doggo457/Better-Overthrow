#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_garrisonLiveJoin
 *
 * Arrival path when the base is SPAWNED (or has no snapshot): the
 * convoy dismounts in the open and the men join the live garrison.
 *
 *   - units + vehicle get the base's garrison/vehgarrison tags, so the
 *     next despawn snapshot captures them (persistence loop closed)
 *   - group + vehicle are appended to the base's OT spawner registry
 *     entry, so fn_despawn actually walks them (unregistered groups
 *     would linger forever and never serialize)
 *   - HAL releases command: op tags stripped, fieldCommand sees a
 *     garrison-role group anchored at the base (leash applies)
 *
 * Params: 0: STRING base, 1: ARRAY base pos, 2: GROUP inf,
 *         3: OBJECT veh, 4: GROUP crew
 * Returns: NUMBER men joined
 */

SERVER_ONLY;
params [
    ["_base", "", [""]],
    ["_pos", [], [[]]],
    ["_grp", grpNull, [grpNull]],
    ["_veh", objNull, [objNull]],
    ["_crewGrp", grpNull, [grpNull]]
];
if (_base isEqualTo "" || {_pos isEqualTo []} || {isNull _grp}) exitWith { 0 };

// ---- dismount + tag ---------------------------------------------------
{
    unassignVehicle _x;
    if (vehicle _x isNotEqualTo _x) then { _x action ["GetOut", vehicle _x] };
    _x setVariable ["garrison", _base, false];
} forEach (units _grp);

if (!isNull _veh && {alive _veh}) then {
    _veh setVariable ["vehgarrison", _base, false];
    { _x setVariable ["garrison", _base, false] } forEach (crew _veh);
};

// ---- fold into the base's spawner registry entry ----------------------
// fn_despawn only walks groups/objects registered with the spawner, so
// without this the new men would never despawn or re-snapshot.
private _sid = "";
{
    private _arr = spawner getVariable [_x, []];
    if (_arr isEqualType [] && {(_arr findIf {
        _x isEqualType grpNull
        && {((units _x) findIf { (_x getVariable ["garrison", ""]) isEqualTo _base }) != -1}
    }) != -1}) exitWith { _sid = _x };
} forEach (allVariables spawner);

if (_sid isNotEqualTo "") then {
    private _arr = spawner getVariable [_sid, []];
    _arr pushBack _grp;
    if (!isNull _veh) then { _arr pushBack _veh };
    if (!isNull _crewGrp && {_crewGrp isNotEqualTo _grp}) then { _arr pushBack _crewGrp };
    spawner setVariable [_sid, _arr, false];
} else {
    private _wmsg = format ["garrisonLiveJoin: no spawner entry found for %1 -- units tagged but unregistered", _base];
    BO_LOG_WARN("hal", _wmsg);
};

// ---- hand off to the world (HAL releases command) ---------------------
{
    private _g = _x;
    if (!isNull _g) then {
        _g setVariable ["BO_HAL_op", nil, false];
        _g setVariable ["BO_HAL_role", "garrison", false];
        _g setVariable ["BO_HAL_anchor", +_pos, false];
        _g setVariable ["BO_HAL_seenAt", serverTime, false];
    };
} forEach [_grp, _crewGrp];

while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
private _wp = _grp addWaypoint [_pos getPos [20 + random 20, random 360], 0];
_wp setWaypointType "MOVE";
_grp setBehaviour "SAFE";
_grp setSpeedMode "LIMITED";
_grp setCombatMode "YELLOW";

private _n = { alive _x } count units _grp;
private _msg = format ["Garrison reinforced (live): +%1 men joined %2", _n, _base];
BO_LOG_INFO("hal", _msg);
_n
