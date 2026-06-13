/*
 * BO mission: Hit NATO Patrol
 *
 * Target = Town (used only as a mission-id anchor; the patrol
 * actually spawns on a road 1-3km from the player's current
 * position, well clear of urban centres).
 *
 * Spawns a random NATO ground-support vehicle with crew on a 250m
 * patrol radius centred on a road segment in the wilderness. Vehicle
 * !alive = success. Crew + vehicle despawn on fail/expire so a
 * patrol the player never engages doesn't sit on the road forever.
 */

params ["_jobid", "_jobparams"];

// Pick a NATO-controlled town (i.e. one NOT in NATOabandoned). We
// take the three nearest to the player and roll one for variety.
private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

// Find a road within 800m of the town centre. Patrol drives around
// it, so the player intercepts the vehicle on a town-perimeter road.
private _roads = (_townPos nearRoads 800) select { _x isKindOf "Road" };
if (_roads isEqualTo []) exitWith { [] };

private _patrolStart = getPos (selectRandom _roads);
if (_patrolStart isEqualTo [0,0,0]) exitWith { [] };

private _vehiclePool = OT_NATO_Vehicles_GroundSupport;
// Faction-aware defensive fallback. Live path uses GroundSupport;
// if a faction doesn't populate it, fall back to the per-map
// Transport_Light single-class which every shipped map defines.
if (isNil "_vehiclePool" || { _vehiclePool isEqualTo [] }) then { _vehiclePool = [OT_NATO_Vehicle_Transport_Light] };
private _vehicleClass = selectRandom _vehiclePool;

private _reward = 3500;
private _vehName = getText (configFile >> "CfgVehicles" >> _vehicleClass >> "displayName");
if (_vehName isEqualTo "") then { _vehName = _vehicleClass };

private _title = format ["Hit NATO Patrol at %1", _townName];
private _description = format [
    "A NATO %1 is running a patrol route around %2 (NATO-held). Locate it on the map and destroy it.<br/><br/>Reward: $%3",
    _vehName, _townName, _reward
];

private _params = [_jobid, _patrolStart, _vehicleClass, _reward];

[
    [_title, _description],
    _patrolStart,
    {
        params ["_jobid", "_patrolStart", "_vehicleClass"];

        private _veh = _vehicleClass createVehicle _patrolStart;
        _veh setVariable ["BO_exempt", true, true];
        createVehicleCrew _veh;
        { _x setVariable ["BO_exempt", true, true] } forEach (crew _veh);
        private _group = group ((crew _veh) param [0, objNull]);

        if (!isNull _group) then {
            [_group, _patrolStart, 250, 4] call CBA_fnc_taskPatrol;
        };

        missionNamespace setVariable [format ["BO_hitPatrol_veh_%1",   _jobid], _veh];
        missionNamespace setVariable [format ["BO_hitPatrol_group_%1", _jobid], _group];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _veh = missionNamespace getVariable [format ["BO_hitPatrol_veh_%1", _jobid], objNull];
        if (isNull _veh) exitWith { false };
        !alive _veh
    },
    {
        params ["_jobid", "", "", "_reward", "_wassuccess"];

        private _veh   = missionNamespace getVariable [format ["BO_hitPatrol_veh_%1",   _jobid], objNull];
        private _group = missionNamespace getVariable [format ["BO_hitPatrol_group_%1", _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [[_veh, _group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_hitPatrol_veh_%1",   _jobid], nil];
        missionNamespace setVariable [format ["BO_hitPatrol_group_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Patrol Strike"] call OT_fnc_money;
        };
    },
    _params
]
