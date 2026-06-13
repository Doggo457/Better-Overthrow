/*
 * BO mission: Sabotage NATO Supply Depot
 *
 * Target = Town. Picks a NATO-controlled town (from the three
 * nearest to the player); the depot lands on the outskirts
 * (200-500m from town centre), inside NATO territory.
 *
 * Layout uses a single _baseDir for orientation:
 *   - Land_Cargo_HQ_V3_F building at centre, facing _baseDir
 *   - Truck parked 18m behind the building (off the back door)
 *   - Crate sits 14m off the building's right side (gate side)
 *   - HBarriers framing the crate (front and back of it) + sandbag
 *     ring round the corners
 *   - 4-person guard squad patrolling 30m around the depot
 *
 * Crate, building, truck, props, and corpses all stay on the map
 * after completion -- BO_fnc_logMissionDebris registers them for
 * delayed despawn (1hr no player within 300m).
 */

params ["_jobid", "_jobparams"];

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

// Bigger clearance than the original placement: a 15m HQ building
// + a 6m truck + a crate + perimeter needs ~25m of free ground.
private _depotPos = [];
for "_attempt" from 1 to 20 do {
    private _candidate = [_townPos, 200, 500, 25, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_candidate isEqualType [] && {(count _candidate) >= 2} && {(_candidate select 0) > 0}) exitWith {
        // findSafePos returns 2D; setPosATL needs 3D.
        _depotPos = [_candidate select 0, _candidate select 1, 0];
    };
};
if (_depotPos isEqualTo []) exitWith { [] };

private _reward = 4500;

private _title = format ["Sabotage Depot at %1", _townName];
private _description = format [
    "NATO has set up a forward supply base on the outskirts of %1 -- a command shack, a supply truck, and a crate guarded by a small detail. Destroy the crate (explosives, vehicle impact, or sustained fire). Drains 50 from NATO resources on success.<br/><br/>The base, truck, and any kit will stay on the ground for you to loot afterwards.<br/><br/>Reward: $%2",
    _townName, _reward
];

private _params = [_jobid, _depotPos, _reward];

[
    [_title, _description],
    _depotPos,
    {
        params ["_jobid", "_depotPos"];

        private _baseDir = random 360;
        private _props = [];

        // 1) Command building at centre.
        private _building = createVehicle ["Land_Cargo_HQ_V3_F", _depotPos, [], 0, "CAN_COLLIDE"];
        _building setDir _baseDir;
        _building setPosATL _depotPos;
        _props pushBack _building;

        // 2) Truck parked 18m off the back of the building.
        private _truckPos = _depotPos getPos [18, _baseDir + 180];
        private _truckPool = OT_NATO_Vehicle_Transport;
        if (isNil "_truckPool" || { _truckPool isEqualTo [] }) then { _truckPool = [OT_NATO_Vehicle_Transport_Light] };
        // "NONE" matches the crate convention -- engine skips placement collision; the explicit setPosATL below decides final pose, avoiding physics ejection when CAN_COLLIDE intersects trees.
        private _truck = createVehicle [selectRandom _truckPool, _truckPos, [], 0, "NONE"];
        _truck setPosATL _truckPos;
        _truck setDir (_baseDir + 90);
        _truck setVariable ["BO_exempt", true, true];
        _props pushBack _truck;

        // 3) Crate 14m off the building's right-hand side, far enough
        //    that HBarriers around it don't intersect the building.
        private _cratePos = _depotPos getPos [14, _baseDir + 90];
        private _crate = "B_supplyCrate_F" createVehicle _cratePos;
        _crate setPosATL _cratePos;
        _crate setVariable ["BO_exempt", true, true];
        _crate allowDamage true;

        // 4) HBarriers framing the crate, sandbag ring at the corners.
        //    All directional pieces oriented to _baseDir so the
        //    installation reads as one placed thing.
        private _hb1 = OT_NATO_Barrier_Small createVehicle (_cratePos getPos [4, _baseDir]);
        _hb1 setDir _baseDir;
        _props pushBack _hb1;
        private _hb2 = OT_NATO_Barrier_Small createVehicle (_cratePos getPos [4, _baseDir + 180]);
        _hb2 setDir (_baseDir + 180);
        _props pushBack _hb2;
        {
            _props pushBack (OT_NATO_Sandbag_Curved createVehicle (_cratePos getPos [3, _x]));
        } forEach [(_baseDir + 45), (_baseDir + 135), (_baseDir + 225), (_baseDir + 315)];

        // 5) 4-person guard squad, patrolling 30m around the depot.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to 4 do {
            // Spawn on a 15-25m ring, not a 0-10m disc: the depot HQ shell is ~10x6m so a disc spawn clips guards into walls.
            private _spawnPos = _depotPos getPos [15 + (random 10), random 360];
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_Depot"] call OT_fnc_initMilitary;
        };
        [_group, _depotPos, 30, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_sabotage_crate_%1",    _jobid], _crate];
        missionNamespace setVariable [format ["BO_sabotage_building_%1", _jobid], _building];
        missionNamespace setVariable [format ["BO_sabotage_truck_%1",    _jobid], _truck];
        missionNamespace setVariable [format ["BO_sabotage_props_%1",    _jobid], _props];
        missionNamespace setVariable [format ["BO_sabotage_group_%1",    _jobid], _group];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _crate = missionNamespace getVariable [format ["BO_sabotage_crate_%1", _jobid], objNull];
        if (isNull _crate) exitWith { false };
        (!alive _crate) || ((damage _crate) > 0.9)
    },
    {
        params ["_jobid", "", "_reward", "_wassuccess"];

        private _crate    = missionNamespace getVariable [format ["BO_sabotage_crate_%1",    _jobid], objNull];
        private _building = missionNamespace getVariable [format ["BO_sabotage_building_%1", _jobid], objNull];
        private _truck    = missionNamespace getVariable [format ["BO_sabotage_truck_%1",    _jobid], objNull];
        private _props    = missionNamespace getVariable [format ["BO_sabotage_props_%1",    _jobid], []];
        private _group    = missionNamespace getVariable [format ["BO_sabotage_group_%1",    _jobid], grpNull];

        // Everything stays in the world -- the depot, the truck, the
        // crate (or its wreck), the bodies, the HBarriers. Hand them
        // all to the long-despawn registry: 1 hour with zero player
        // presence within 300m before any of it gets cleaned up.
        private _allDebris = _props + [_crate, _building, _truck, _group];
        if (alive _truck) then {
            // Let OT GC keep its hands off the truck -- it's loot.
            _truck setVariable ["BO_exempt", false, true];
        };
        // Re-expose the bodies to OT garbage collector once mission is
        // over (they have their own timed sweep).
        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [_allDebris] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_sabotage_crate_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_sabotage_building_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_sabotage_truck_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_sabotage_props_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_sabotage_group_%1",    _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Supply Sabotage"] call OT_fnc_money;
            private _natoRes = server getVariable ["NATOresources", 0];
            server setVariable ["NATOresources", (_natoRes - 50) max 0, true];
        };
    },
    _params
]
