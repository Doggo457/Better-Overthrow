/*
 * BO mission: Hit NATO AAA
 *
 * Target = Town (id anchor). The AA emplacement spawns inside a
 * NATO-controlled BASE (OT_objectiveData) -- airport, military
 * installation, etc. -- not just at the edge of a town. NATO
 * doesn't park AA in farmland; it's at bases.
 *
 * Static B_static_AA_F + crew + 2 foot guards. Destroying it
 * drains 75 NATOresources on success.
 *
 * Compound stays in the world via long-despawn.
 */

params ["_jobid", "_jobparams"];

private _abandoned = server getVariable ["NATOabandoned", []];

// Prefer NATO-controlled OT objectives (bases, airports, comm
// installations). Fall back to NATO towns only if no live bases
// are available (early-game resistance scenario).
private _natoObjs = (if (isNil "OT_objectiveData") then { [] } else { OT_objectiveData })
    select { !((_x select 1) in _abandoned) };
if (_natoObjs isEqualTo []) then {
    private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
    _natoObjs = _natoTowns;
};
if (_natoObjs isEqualTo []) exitWith { [] };

private _sorted = [_natoObjs, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _obj = selectRandom _candidates;
_obj params ["_objPos", "_objName"];

// AA position INSIDE the base -- 50-150m from objective centre.
private _aaPos = [];
for "_attempt" from 1 to 20 do {
    private _candidate = [_objPos, 50, 150, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_candidate isEqualType [] && {(count _candidate) >= 2} && {(_candidate select 0) > 0}) exitWith {
        // findSafePos returns 2D; downstream setPosATL needs 3D.
        _aaPos = [_candidate select 0, _candidate select 1, 0];
    };
};
if (_aaPos isEqualTo []) exitWith { [] };

private _reward = 5500;

private _title = format ["Hit AAA at %1", _objName];
private _description = format [
    "NATO has a static AA position deployed at %1. Destroy it -- explosives or sustained AT work best. Strategic effect: -75 NATO resources.<br/><br/>Reward: $%2",
    _objName, _reward
];

private _params = [_jobid, _aaPos, _reward];

[
    [_title, _description],
    _aaPos,
    {
        params ["_jobid", "_aaPos"];

        private _baseDir = random 360;
        private _props = [];

        // Map-portable AA class. Many non-vanilla factions (RHS/CUP)
        // don't populate OT_NATO_Vehicles_StaticAAGarrison -- in those
        // cases the fallback DOES fire. We accept the vanilla BLU_F
        // Cheetah as last resort because the AAA mission is
        // fundamentally about killing an anti-air emplacement; an
        // HMG/MRAP swap would change the mission's meaning. If the
        // faction populates the var, we use it.
        private _aaPool = if (!isNil "OT_NATO_Vehicles_StaticAAGarrison" && {(OT_NATO_Vehicles_StaticAAGarrison) isNotEqualTo []}) then {
            OT_NATO_Vehicles_StaticAAGarrison
        } else {
            ["B_Static_AA_F"]
        };
        private _aaClass = selectRandom _aaPool;

        private _aa = _aaClass createVehicle _aaPos;
        _aa setPosATL _aaPos;
        _aa setDir _baseDir;
        _aa setVariable ["BO_exempt", true, true];
        _aa allowDamage true;
        createVehicleCrew _aa;
        { _x setVariable ["BO_exempt", true, true] } forEach (crew _aa);
        private _aaGroup = group ((crew _aa) param [0, objNull]);

        // Sandbag ring
        {
            _props pushBack (OT_NATO_Sandbag_Curved createVehicle (_aaPos getPos [4, _x]));
        } forEach [_baseDir, (_baseDir + 90), (_baseDir + 180), (_baseDir + 270)];

        // Foot guards go in a SEPARATE group -- taskPatrol on the crew
        // group would walk the gunner off the AA gun within seconds.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to 2 do {
            private _spawnPos = _aaPos getPos [random 6, random 360];
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_AAA"] call OT_fnc_initMilitary;
        };
        [_group, _aaPos, 20, 3] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_aaa_emplacement_%1", _jobid], _aa];
        missionNamespace setVariable [format ["BO_aaa_props_%1",       _jobid], _props];
        missionNamespace setVariable [format ["BO_aaa_group_%1",       _jobid], _group];
        missionNamespace setVariable [format ["BO_aaa_aaGroup_%1",     _jobid], _aaGroup];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _aa = missionNamespace getVariable [format ["BO_aaa_emplacement_%1", _jobid], objNull];
        if (isNull _aa) exitWith { false };
        (!alive _aa) || ((damage _aa) > 0.9)
    },
    {
        params ["_jobid", "", "_reward", "_wassuccess"];

        private _aa      = missionNamespace getVariable [format ["BO_aaa_emplacement_%1", _jobid], objNull];
        private _props   = missionNamespace getVariable [format ["BO_aaa_props_%1",       _jobid], []];
        private _group   = missionNamespace getVariable [format ["BO_aaa_group_%1",       _jobid], grpNull];
        private _aaGroup = missionNamespace getVariable [format ["BO_aaa_aaGroup_%1",     _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        // Foot guards and AA crew live in separate groups now -- clean both.
        if (!isNull _aaGroup) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _aaGroup);
        };
        [_props + [_aa, _group, _aaGroup]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_aaa_emplacement_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_aaa_props_%1",       _jobid], nil];
        missionNamespace setVariable [format ["BO_aaa_group_%1",       _jobid], nil];
        missionNamespace setVariable [format ["BO_aaa_aaGroup_%1",     _jobid], nil];

        if (_wassuccess) then {
            [_reward, "AAA Strike"] call OT_fnc_money;
            private _natoRes = server getVariable ["NATOresources", 0];
            server setVariable ["NATOresources", (_natoRes - 75) max 0, true];
        };
    },
    _params
]
