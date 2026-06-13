/*
 * BO mission: Disable Radar Dish
 *
 * NATO has erected a comm tower with a radar dish on the outskirts
 * of a NATO-held town. Player destroys the dish (or the entire
 * tower) -- this is a new spawned installation, not the OT-grid
 * Radar build. Drains 80 NATO resources on success.
 *
 * Layout: tower (OT_NATO_CommTowers, fallback Land_TTowerBig_1_F),
 * a Land_SatelliteAntenna_01_F dish placed on top, sandbag
 * perimeter, defended by 4 patrolling NATO foot guards.
 */

params ["_jobid", "_jobparams"];

if (isNil "OT_townData" || { OT_townData isEqualTo [] }) exitWith { [] };

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

private _radarPos = [];
for "_attempt" from 1 to 20 do {
    private _c = [_townPos, 300, 600, 25, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_c isEqualType [] && {(count _c) >= 2} && {(_c select 0) > 0}) exitWith {
        _radarPos = [_c select 0, _c select 1, 0];
    };
};
if (_radarPos isEqualTo []) exitWith { [] };

private _reward = 5000;
private _title = format ["Disable Radar Dish near %1", _townName];
private _description = format [
    "NATO has erected a comm tower with a radar dish near %1. Knock out the dish (explosives or sustained AT) or take down the whole tower. Drains 80 NATO resources on success.<br/><br/>Reward: $%2",
    _townName, _reward
];

private _params = [_jobid, _radarPos, _reward];

[
    [_title, _description],
    _radarPos,
    {
        params ["_jobid", "_radarPos"];

        private _baseDir = random 360;
        private _props = [];

        private _towerPool = if (isNil "OT_NATO_CommTowers") then { ["Land_TTowerBig_1_F"] } else { OT_NATO_CommTowers };
        if (_towerPool isEqualTo []) then { _towerPool = ["Land_TTowerBig_1_F"] };
        private _tower = createVehicle [selectRandom _towerPool, _radarPos, [], 0, "CAN_COLLIDE"];
        _tower setPosATL _radarPos;
        _tower setDir _baseDir;
        _tower setVariable ["BO_exempt", true, true];
        _tower allowDamage true;

        // Dish prop placed on top of the tower bbox.
        private _bbox = boundingBoxReal _tower;
        private _topZ = (_bbox select 1 select 2);
        private _dishPos = _tower modelToWorld [0, 0, _topZ - 0.5];
        private _dish = createVehicle ["Land_SatelliteAntenna_01_F", _dishPos, [], 0, "NONE"];
        _dish setPosATL _dishPos;
        _dish setDir _baseDir;
        _dish setVariable ["BO_exempt", true, true];
        _dish allowDamage true;

        _props pushBack _tower;

        // Sandbag perimeter ring round the tower base.
        {
            _props pushBack (OT_NATO_Sandbag_Curved createVehicle (_radarPos getPos [4.5, _x]));
        } forEach [_baseDir, _baseDir + 90, _baseDir + 180, _baseDir + 270];

        // 4-person foot guard patrol.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to 4 do {
            private _spawnPos = _radarPos getPos [18 + (random 8), random 360];
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_RadarDish"] call OT_fnc_initMilitary;
        };
        [_group, _radarPos, 30, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_radar_tower_%1", _jobid], _tower];
        missionNamespace setVariable [format ["BO_radar_dish_%1",  _jobid], _dish];
        missionNamespace setVariable [format ["BO_radar_props_%1", _jobid], _props];
        missionNamespace setVariable [format ["BO_radar_group_%1", _jobid], _group];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _dish  = missionNamespace getVariable [format ["BO_radar_dish_%1",  _jobid], objNull];
        private _tower = missionNamespace getVariable [format ["BO_radar_tower_%1", _jobid], objNull];
        if (isNull _dish && isNull _tower) exitWith { false };
        ((!alive _dish) || ((damage _dish) > 0.9)) || ((!alive _tower) || ((damage _tower) > 0.9))
    },
    {
        params ["_jobid", "", "_reward", "_wassuccess"];

        private _tower = missionNamespace getVariable [format ["BO_radar_tower_%1", _jobid], objNull];
        private _dish  = missionNamespace getVariable [format ["BO_radar_dish_%1",  _jobid], objNull];
        private _props = missionNamespace getVariable [format ["BO_radar_props_%1", _jobid], []];
        private _group = missionNamespace getVariable [format ["BO_radar_group_%1", _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [_props + [_tower, _dish, _group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_radar_tower_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_radar_dish_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_radar_props_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_radar_group_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Disabled Radar"] call OT_fnc_money;
            private _natoRes = server getVariable ["NATOresources", 0];
            server setVariable ["NATOresources", (_natoRes - 80) max 0, true];
        };
    },
    _params
]
