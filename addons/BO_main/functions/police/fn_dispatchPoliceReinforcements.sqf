#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_dispatchPoliceReinforcements
 *
 * Server-only. Finds the nearest non-captured police station to the
 * target, spawns a 5-unit SWAT group + police vehicle at that
 * station, and tasks them to drive to the capture target. They
 * engage the player on arrival.
 *
 * The convoy group is stashed on BO_polcap_reinforce_<town> so
 * fail/success paths can clean it up.
 *
 * Params:
 *   0: STRING - target town name (the station under attack)
 *   1: ARRAY  - target station position
 */

if (!isServer) exitWith {};

params [
    ["_targetTown", "", [""]],
    ["_targetPos", [0,0,0], [[]]]
];
if (_targetTown isEqualTo "") exitWith {};

private _stations = server getVariable ["BO_natoPoliceStations", []];

// Pick the nearest non-captured, non-target station.
private _sourceEntry = [];
private _bestDist = 1e9;
{
    if ((_x select 0) isEqualTo _targetTown) then { continue };
    if (_x select 2) then { continue };
    private _d = _targetPos distance2D (_x select 1);
    if (_d < _bestDist) then {
        _bestDist = _d;
        _sourceEntry = _x;
    };
} forEach _stations;

if (_sourceEntry isEqualTo []) exitWith {
    private _msg = format ["dispatchPoliceReinforcements: no other station available for %1", _targetTown];
    BO_LOG_INFO("police", _msg);
    "No other police stations available -- you fight alone" remoteExec ["OT_fnc_notifyMinor", 0, false];
};

private _sourcePos = _sourceEntry select 1;
private _sourceTown = _sourceEntry select 0;

// Spawn convoy at the source station -- 1 vehicle + 5 SWAT.
// Faction-aware fallbacks -- non-vanilla factions without
// Gendarmerie classes spawn the per-map Transport_Light + TeamLeader
// instead of a hardcoded BLU_F Gendarmerie Offroad.
private _vehCls = if (!isNil "OT_NATO_Vehicle_Police") then { OT_NATO_Vehicle_Police } else { OT_NATO_Vehicle_Transport_Light };
private _commanderCls = if (!isNil "OT_NATO_Unit_PoliceCommander_Heavy") then { OT_NATO_Unit_PoliceCommander_Heavy } else { OT_NATO_Unit_TeamLeader };
private _soldierCls   = if (!isNil "OT_NATO_Unit_Police_Heavy")          then { OT_NATO_Unit_Police_Heavy }          else { OT_NATO_Unit_TeamLeader };

// Anchor convoy spawn to the nearest road + findEmptyPosition with the
// vehicle's own bbox so the car doesn't materialise inside a wall /
// fence / other vehicle and get detonated by the physics resolver.
// Mirrors fn_spawnPoliceStationGarrison.sqf vehicle placement.
private _road = [_sourcePos] call BIS_fnc_nearestRoad;
private _convoyPos = [];
if (!isNull _road && {(_road distance2D _sourcePos) < 120}) then {
    _convoyPos = (getPos _road) findEmptyPosition [4, 40, _vehCls];
    if (_convoyPos isEqualTo []) then { _convoyPos = getPos _road };
} else {
    _convoyPos = _sourcePos findEmptyPosition [10, 50, _vehCls];
    if (_convoyPos isEqualTo []) then { _convoyPos = _sourcePos getPos [25, random 360] };
};
private _veh = createVehicle [_vehCls, _convoyPos, [], 0, "NONE"];
_veh setPosATL _convoyPos;
// Orient down the road if we anchored there, else face the target.
if (!isNull _road) then {
    private _roadsTo = roadsConnectedTo _road;
    if (count _roadsTo > 0) then {
        _veh setDir (_road getDir (_roadsTo select 0));
    } else {
        _veh setDir (_convoyPos getDir _targetPos);
    };
} else {
    _veh setDir (_convoyPos getDir _targetPos);
};
_veh setVariable ["BO_polReinforceConvoy", _targetTown, true];
_veh setVariable ["BO_exempt", true, true];

private _grp = createGroup [blufor, true];
private _crewClasses = [_commanderCls, _soldierCls, _soldierCls, _soldierCls, _soldierCls];
{
    private _u = _grp createUnit [_x, _convoyPos, [], 0, "NONE"];
    _u setVariable ["BO_polReinforceConvoy", _targetTown, true];
    _u setVariable ["BO_exempt", true, true];
} forEach _crewClasses;

// Mount crew deterministically -- leader in driver seat, rest in cargo.
// moveInAny would let the leader land in cargo, after which assignAsDriver
// only takes effect on the next get-in cycle and the convoy never moves.
private _leader = leader _grp;
_leader assignAsDriver _veh;
_leader moveInDriver _veh;
{
    _x assignAsCargo _veh;
    _x moveInCargo _veh;
} forEach ((units _grp) - [_leader]);

// Drive-to waypoint + SAD on arrival.
private _wp1 = _grp addWaypoint [_targetPos, 0];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointSpeed "FULL";
_wp1 setWaypointCombatMode "RED";
_wp1 setWaypointBehaviour "AWARE";

private _wp2 = _grp addWaypoint [_targetPos, 0];
_wp2 setWaypointType "SAD";
_wp2 setWaypointSpeed "NORMAL";
_wp2 setWaypointCombatMode "RED";
// Dismount on arrival so they actually engage on foot. Statement string
// is parsed without preprocessor, so // comments and multi-line whitespace
// crash the parser ("Invalid number in expression"). Keep this on one line.
_wp2 setWaypointStatements ["true", "{unassignVehicle _x; _x leaveVehicle vehicle _x; [_x] orderGetIn false} forEach units group this"];

missionNamespace setVariable [format ["BO_polcap_reinforce_%1", _targetTown], [_grp, _veh], true];

private _msg = format ["Police reinforcements en route from %1 (%2m away)", _sourceTown, round _bestDist];
_msg remoteExec ["OT_fnc_notifyMinor", 0, false];
private _lmsg = format ["Reinforcements dispatched: %1 -> %2 (%3m)", _sourceTown, _targetTown, round _bestDist];
BO_LOG_INFO("police", _lmsg);
