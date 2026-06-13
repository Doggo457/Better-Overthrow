/*
 * BO mission: Hit NATO Checkpoint
 *
 * Target = Town. Spawns a NATO checkpoint on a road within 600m of
 * a NATO-controlled town: HBarriers + sandbags + 4 NATO infantry +
 * 1 mounted HMG. Player kills all infantry + destroys/captures the
 * HMG by killing its gunner. Stationary defensive setup makes it
 * different from the mobile Hit Patrol mission.
 *
 * All classes from OT globals (OT_NATO_*) so the mission is map-
 * portable across Altis / Malden / Tanoa / Livonia.
 */

params ["_jobid", "_jobparams"];

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

private _roads = (_townPos nearRoads 600) select { _x isKindOf "Road" };
if (_roads isEqualTo []) exitWith { [] };
private _checkpointPos = getPos (selectRandom _roads);
if (_checkpointPos isEqualTo [0,0,0]) exitWith { [] };

private _reward = 3500;
private _numToKill = 4;

private _title = format ["Hit Checkpoint at %1", _townName];
private _description = format [
    "NATO has thrown up a checkpoint on a road near %1 (HMG, HBarriers, 4 infantry). Wipe it out. Loot the position on success.<br/><br/>Reward: $%2",
    _townName, _reward
];

private _params = [_jobid, _checkpointPos, _numToKill, _reward];

[
    [_title, _description],
    _checkpointPos,
    {
        params ["_jobid", "_checkpointPos", "_numToKill"];

        private _baseDir = (selectRandom [0, 90, 180, 270]);
        private _props = [];

        // HBarriers + sandbag perimeter
        private _hb1 = OT_NATO_Barrier_Small createVehicle (_checkpointPos getPos [4, _baseDir]);
        _hb1 setDir _baseDir; _props pushBack _hb1;
        private _hb2 = OT_NATO_Barrier_Small createVehicle (_checkpointPos getPos [4, _baseDir + 180]);
        _hb2 setDir (_baseDir + 180); _props pushBack _hb2;
        {
            _props pushBack (OT_NATO_Sandbag_Curved createVehicle (_checkpointPos getPos [3, _x]));
        } forEach [(_baseDir + 90), (_baseDir + 270)];

        // Mounted HMG with crew
        private _hmg = OT_NATO_HMG createVehicle (_checkpointPos getPos [2, _baseDir + 90]);
        _hmg setDir (_baseDir + 90);
        _hmg setVariable ["BO_exempt", true, true];
        createVehicleCrew _hmg;
        { _x setVariable ["BO_exempt", true, true] } forEach (crew _hmg);
        private _hmgGroup = group ((crew _hmg) param [0, objNull]);

        // Foot infantry in a SEPARATE group -- taskPatrol on the crew
        // group would walk the gunner off the HMG within seconds.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to _numToKill do {
            private _spawnPos = _checkpointPos getPos [random 5, random 360];
            private _unit = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _unit setVariable ["BO_exempt", true, true];
            [_unit, "BO_Checkpoint"] call OT_fnc_initMilitary;
        };
        [_group, _checkpointPos, 15, 3] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_checkpoint_group_%1",    _jobid], _group];
        missionNamespace setVariable [format ["BO_checkpoint_props_%1",    _jobid], _props];
        missionNamespace setVariable [format ["BO_checkpoint_hmg_%1",      _jobid], _hmg];
        missionNamespace setVariable [format ["BO_checkpoint_hmgGroup_%1", _jobid], _hmgGroup];
        true
    },
    {
        false
    },
    {
        params ["_jobid", "", "_numToKill"];
        private _group    = missionNamespace getVariable [format ["BO_checkpoint_group_%1",    _jobid], grpNull];
        private _hmgGroup = missionNamespace getVariable [format ["BO_checkpoint_hmgGroup_%1", _jobid], grpNull];
        if (isNull _group) exitWith { false };
        // Foot infantry and HMG crew now in separate groups -- success
        // requires both wiped.
        private _footAlive = { alive _x } count (units _group);
        private _crewAlive = if (isNull _hmgGroup) then { 0 } else { { alive _x } count (units _hmgGroup) };
        (_footAlive + _crewAlive) isEqualTo 0
    },
    {
        params ["_jobid", "", "", "_reward", "_wassuccess"];

        private _group    = missionNamespace getVariable [format ["BO_checkpoint_group_%1",    _jobid], grpNull];
        private _props    = missionNamespace getVariable [format ["BO_checkpoint_props_%1",    _jobid], []];
        private _hmg      = missionNamespace getVariable [format ["BO_checkpoint_hmg_%1",      _jobid], objNull];
        private _hmgGroup = missionNamespace getVariable [format ["BO_checkpoint_hmgGroup_%1", _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        // Foot infantry and HMG crew live in separate groups -- clean both.
        if (!isNull _hmgGroup) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _hmgGroup);
        };
        [_props + [_hmg, _group, _hmgGroup]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_checkpoint_group_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_checkpoint_props_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_checkpoint_hmg_%1",      _jobid], nil];
        missionNamespace setVariable [format ["BO_checkpoint_hmgGroup_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Checkpoint Strike"] call OT_fnc_money;
        };
    },
    _params
]
