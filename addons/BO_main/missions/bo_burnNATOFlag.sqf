/*
 * BO mission: Burn NATO Flag
 *
 * NATO has planted a flag at a small forward post outside a
 * NATO-held town. Player burns it via a 5-second hold action.
 * Light garrison: 3 patrolling guards.
 *
 * Reward: $2500 + 20 standing in the host town.
 *
 * Uses vanilla addAction + spawn-sleep, no ACE dependency.
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

private _postPos = [];
for "_attempt" from 1 to 15 do {
    private _c = [_townPos, 200, 450, 15, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_c isEqualType [] && {(count _c) >= 2} && {(_c select 0) > 0}) exitWith {
        _postPos = [_c select 0, _c select 1, 0];
    };
};
if (_postPos isEqualTo []) exitWith { [] };

private _reward = 2500;
private _title = format ["Burn NATO Flag near %1", _townName];
private _description = format [
    "NATO planted a flag at a small forward post near %1. Burn it -- a symbolic blow that'll rally the town. Three guards on patrol.<br/><br/>Reward: $%2 + standing in %1.",
    _townName, _reward
];

private _params = [_jobid, _postPos, _townName, _reward];

[
    [_title, _description],
    _postPos,
    {
        params ["_jobid", "_postPos"];

        private _baseDir = random 360;
        private _props = [];

        // Sandbag pen.
        {
            _props pushBack (OT_NATO_Sandbag_Curved createVehicle (_postPos getPos [3, _x]));
        } forEach [_baseDir, _baseDir + 90, _baseDir + 180, _baseDir + 270];

        // Flagpole.
        private _pole = createVehicle ["Flag_NATO_F", _postPos, [], 0, "NONE"];
        _pole setPosATL _postPos;
        _pole setDir _baseDir;
        _pole setVariable ["BO_exempt", true, true];
        _pole setFlagTexture "\A3\Data_F\Flags\flag_nato_co.paa";

        // 5-second hold-action burn (vanilla, no ACE).
        private _act = _pole addAction [
            "<t color='#ff8040'>Burn Flag (5s)</t>",
            {
                params ["_t", "_caller", "_jobid"];
                [_jobid, _t, _caller] spawn {
                    params ["_jobid", "_t", "_caller"];
                    "Burning flag..." call OT_fnc_notifyMinor;
                    sleep 5;
                    if (!alive _caller
                        || {_caller distance _t > 3}
                        || {vehicle _caller isNotEqualTo _caller}) exitWith {
                        "Interrupted." call OT_fnc_notifyMinor;
                    };
                    missionNamespace setVariable [format ["BO_flag_burned_%1", _jobid], true, true];
                    private _fire = "#particlesource" createVehicleLocal getPosATL _t;
                    _fire setParticleClass "BarrelFire";
                    _fire attachTo [_t, [0, 0, 5]];
                    _t setFlagTexture "";
                    "NATO flag burned." call OT_fnc_notifyGood;
                };
            },
            _jobid,
            1.5,
            true,
            true,
            "",
            "_this distance _target < 3 && (vehicle _this isEqualTo _this)"
        ];

        // 3 patrolling guards.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to 3 do {
            private _spawnPos = _postPos getPos [12 + (random 8), random 360];
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_BurnFlag"] call OT_fnc_initMilitary;
        };
        [_group, _postPos, 25, 3] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_flag_object_%1", _jobid], _pole];
        missionNamespace setVariable [format ["BO_flag_props_%1",  _jobid], _props];
        missionNamespace setVariable [format ["BO_flag_group_%1",  _jobid], _group];
        missionNamespace setVariable [format ["BO_flag_burned_%1", _jobid], false];
        missionNamespace setVariable [format ["BO_flag_action_%1", _jobid], _act];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        missionNamespace getVariable [format ["BO_flag_burned_%1", _jobid], false]
    },
    {
        params ["_jobid", "", "_townName", "_reward", "_wassuccess"];

        private _pole  = missionNamespace getVariable [format ["BO_flag_object_%1", _jobid], objNull];
        private _props = missionNamespace getVariable [format ["BO_flag_props_%1",  _jobid], []];
        private _group = missionNamespace getVariable [format ["BO_flag_group_%1",  _jobid], grpNull];
        private _act   = missionNamespace getVariable [format ["BO_flag_action_%1", _jobid], -1];

        if (!isNull _pole && _act >= 0) then { _pole removeAction _act };
        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [_props + [_pole, _group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_flag_object_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_flag_props_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_flag_group_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_flag_burned_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_flag_action_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Burned NATO Flag"] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                [_townName, 20, format ["Burned a NATO flag near %1", _townName]] call OT_fnc_support;
            };
        };
    },
    _params
]
