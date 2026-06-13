/*
 * BO mission: Raid NATO SF Camp
 *
 * Target = Town. The town is just a stable mission-id anchor; the
 * actual camp gets placed in the wilderness 1.5-3km from the player
 * via BIS_fnc_findSafePos with a large object-clearance filter, so
 * the encounter feels like "NATO has set up a temporary forward
 * outpost in the middle of nowhere" rather than "another mission
 * stuck to an existing OT base/town".
 *
 * Setup spawns a tent + ammo crate + sandbag perimeter + 6 SF
 * operators on patrol. Crate stays after success for the player to
 * loot; corpses skip the garbage collector. On fail/expire the
 * entire camp despawns cleanly.
 *
 * State keyed on _jobid so concurrent raid missions don't collide.
 */

params ["_jobid", "_jobparams"];

private _anchorPos = getPos player;
if (_anchorPos isEqualTo [0,0,0]) exitWith { [] };

// Forest-weighted placement, the same pattern OT uses for placing
// hidden businesses (fn_initEconomyLoad.sqf:26). The formula
// "(1 + forest + trees) * (1 - houses) * (1 - sea)" biases hard
// toward wooded terrain and subtracts urban / water. Returns the
// 30 best places within 6km.
private _places = selectBestPlaces [_anchorPos, 6000, "(1 + forest + trees) * (1 - houses) * (1 - sea)", 30, 30];

// Trim to candidates >= 3km from the player (user spec) and far
// enough from any airport. pushBack form is intentional -- a `select
// { ... }` with a nested exitWith returned Bool instead of Array on
// some SQF builds, so we walk the array explicitly.
private _airports = if (isNil "OT_airportData") then { [] } else { OT_airportData };
if (typeName _places != "ARRAY") exitWith { [] };

private _candidates = [];
{
    private _p = _x select 0;
    if ((_p distance2D _anchorPos) >= 3000) then {
        private _nearAirport = false;
        {
            if (!_nearAirport && { ((_x select 0) distance2D _p) < 1500 }) then {
                _nearAirport = true;
            };
        } forEach _airports;
        if (!_nearAirport) then { _candidates pushBack _x };
    };
} forEach _places;

if (_candidates isEqualTo []) exitWith { [] };

// Pick from the top of the forest-score ranking with some randomness.
private _cnt = count _candidates;
private _topN = _candidates select [0, 5 min _cnt];
private _campPos = (selectRandom _topN) select 0;
if (_campPos isEqualTo [0,0,0]) exitWith { [] };

private _reward = 5500;
private _numToKill = 6;

private _title = "Raid SF Camp";
private _description = format [
    "NATO Special Forces have set up a temporary forward outpost out in the wilderness, well clear of any town. Locate the camp, eliminate all %1 operators, and take anything worth taking. Loot stays behind on success.<br/><br/>Reward: $%2",
    _numToKill, _reward
];

private _params = [_jobid, _campPos, _numToKill, _reward];

[
    [_title, _description],
    _campPos,
    {
        params ["_jobid", "_campPos", "_numToKill"];

        // Forest bias + createVehicle ignoring terrain objects = props
        // clipping into trees. For each offset prop, rotate the angle
        // until we find a clear spot; fallback to the original angle.
        private _fnc_clearOffset = {
            params ["_origin", "_dist", "_startAngle"];
            private _result = _origin getPos [_dist, _startAngle];
            for "_step" from 0 to 11 do {
                private _ang = (_startAngle + (_step * 30)) mod 360;
                private _candidate = _origin getPos [_dist, _ang];
                if ((nearestTerrainObjects [_candidate, ["Tree", "Bush"], 3.0]) isEqualTo []) exitWith {
                    _result = _candidate;
                };
            };
            _result
        };

        private _props = [];
        // Tent sits on the centre point -- only place if the centre is
        // clear; otherwise nudge it to the first clear offset 2m out.
        private _tentPos = if ((nearestTerrainObjects [_campPos, ["Tree", "Bush"], 3.0]) isEqualTo []) then {
            _campPos
        } else {
            [_campPos, 2, random 360] call _fnc_clearOffset
        };
        _props pushBack ("Land_TentA_F"                     createVehicle _tentPos);
        _props pushBack ("B_supplyCrate_F"                  createVehicle ([_campPos, 3, 90]  call _fnc_clearOffset));
        _props pushBack ("Land_BagFence_01_round_green_F"   createVehicle ([_campPos, 4, 0]   call _fnc_clearOffset));
        _props pushBack ("Land_BagFence_01_round_green_F"   createVehicle ([_campPos, 4, 120] call _fnc_clearOffset));
        _props pushBack ("Land_BagFence_01_round_green_F"   createVehicle ([_campPos, 4, 240] call _fnc_clearOffset));

        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelTwo + OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };

        for "_i" from 1 to _numToKill do {
            private _spawnPos = _campPos getPos [random 8, random 360];
            private _unit = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _unit setVariable ["BO_exempt", true, true];
            [_unit, "BO_SFCamp"] call OT_fnc_initMilitary;
        };
        [_group, _campPos, 30, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_raidSF_group_%1", _jobid], _group];
        missionNamespace setVariable [format ["BO_raidSF_props_%1", _jobid], _props];
        true
    },
    {
        false
    },
    {
        params ["_jobid", "", "_numToKill"];
        private _group = missionNamespace getVariable [format ["BO_raidSF_group_%1", _jobid], grpNull];
        if (isNull _group) exitWith { false };
        private _numAlive = { alive _x } count (units _group);
        private _killed = _numToKill - _numAlive;
        // PFH ticks every 2s; unconditional `hint` chimes every tick.
        // Cache last-known kill count per job and only hintSilent on change.
        private _key = format ["BO_raidSF_lastKills_%1", _jobid];
        private _last = missionNamespace getVariable [_key, -1];
        if (_killed != _last) then {
            missionNamespace setVariable [_key, _killed];
            hintSilent format ["SF eliminated: %1/%2", _killed, _numToKill];
        };
        _numAlive isEqualTo 0
    },
    {
        params ["_jobid", "", "", "_reward", "_wassuccess"];

        private _props = missionNamespace getVariable [format ["BO_raidSF_props_%1", _jobid], []];
        private _group = missionNamespace getVariable [format ["BO_raidSF_group_%1", _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [_props + [_group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_raidSF_props_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_raidSF_group_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_raidSF_lastKills_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "SF Camp Raid"] call OT_fnc_money;
        };
    },
    _params
]
