/*
 * BO mission: Burn Fuel Cache
 *
 * NATO has stockpiled fuel drums on the outskirts of a NATO-held
 * town. Player ignites the cache via addAction on any drum, by
 * destroying drums with explosives or sustained fire (50%+),
 * or with vehicle impact. Drains 60 NATO resources on success.
 *
 * Layout: 12 sand-grey barrels in a 3x4 grid with a sandbag
 * perimeter, defended by 4 patrolling NATO foot guards.
 *
 * Drums, sandbags, and corpses persist 1hr via BO_fnc_logMissionDebris.
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

private _cachePos = [];
for "_attempt" from 1 to 20 do {
    private _c = [_townPos, 200, 500, 18, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_c isEqualType [] && {(count _c) >= 2} && {(_c select 0) > 0}) exitWith {
        _cachePos = [_c select 0, _c select 1, 0];
    };
};
if (_cachePos isEqualTo []) exitWith { [] };

private _reward = 3500;
private _title = format ["Burn Fuel Cache near %1", _townName];
private _description = format [
    "NATO is stockpiling fuel in drums on the outskirts of %1. Find the cache and ignite it -- interact with any drum (Ignite Cache), destroy it with explosives, or sustain enough fire to crack open half the barrels. Drains 60 NATO resources on success.<br/><br/>Reward: $%2",
    _townName, _reward
];

private _params = [_jobid, _cachePos, _reward];

[
    [_title, _description],
    _cachePos,
    {
        params ["_jobid", "_cachePos"];

        private _baseDir = random 360;
        private _props = [];
        private _drums = [];

        // 12 drums in a 3x4 grid, oriented to _baseDir.
        for "_row" from 0 to 3 do {
            for "_col" from 0 to 2 do {
                private _offsetDist = 1.6 + (sqrt ((_row * _row) + (_col * _col)));
                private _offsetDir = _baseDir + (25 * _row) + (60 * _col);
                private _p = _cachePos getPos [_offsetDist, _offsetDir];
                private _d = createVehicle ["Land_BarrelSand_grey_F", _p, [], 0, "NONE"];
                _d setPosATL [_p select 0, _p select 1, 0];
                _d setVariable ["BO_exempt", true, true];
                _d allowDamage true;
                // Ignite addAction: on foot, within 3m, broadcasts the burned flag.
                _d addAction [
                    "<t color='#ff4040'>Ignite Cache</t>",
                    {
                        params ["_t", "_caller", "_jobid"];
                        missionNamespace setVariable [format ["BO_fuelcache_burned_%1", _jobid], true, true];
                        private _fire = "#particlesource" createVehicleLocal getPosATL _t;
                        _fire setParticleClass "BarrelFire";
                        _fire attachTo [_t, [0, 0, 0]];
                        _t setDamage 1;
                        "Fuel cache ignited." call OT_fnc_notifyMinor;
                    },
                    _jobid,
                    1.5,
                    true,
                    true,
                    "",
                    "_this distance _target < 3 && (vehicle _this isEqualTo _this)"
                ];
                _drums pushBack _d;
            };
        };

        // Sandbag perimeter ring.
        {
            _props pushBack (OT_NATO_Sandbag_Curved createVehicle (_cachePos getPos [4.5, _x]));
        } forEach [_baseDir, _baseDir + 90, _baseDir + 180, _baseDir + 270];

        // 4-person foot guard patrol.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to 4 do {
            private _spawnPos = _cachePos getPos [15 + (random 10), random 360];
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_FuelCache"] call OT_fnc_initMilitary;
        };
        [_group, _cachePos, 25, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_fuelcache_drums_%1",  _jobid], _drums];
        missionNamespace setVariable [format ["BO_fuelcache_props_%1",  _jobid], _props];
        missionNamespace setVariable [format ["BO_fuelcache_group_%1",  _jobid], _group];
        missionNamespace setVariable [format ["BO_fuelcache_burned_%1", _jobid], false];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _burned = missionNamespace getVariable [format ["BO_fuelcache_burned_%1", _jobid], false];
        if (_burned) exitWith { true };
        private _drums = missionNamespace getVariable [format ["BO_fuelcache_drums_%1", _jobid], []];
        if (_drums isEqualTo []) exitWith { false };
        private _dead = { !alive _x } count _drums;
        _dead >= 6
    },
    {
        params ["_jobid", "", "_reward", "_wassuccess"];

        private _drums  = missionNamespace getVariable [format ["BO_fuelcache_drums_%1",  _jobid], []];
        private _props  = missionNamespace getVariable [format ["BO_fuelcache_props_%1",  _jobid], []];
        private _group  = missionNamespace getVariable [format ["BO_fuelcache_group_%1",  _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [_props + _drums + [_group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_fuelcache_drums_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_fuelcache_props_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_fuelcache_group_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_fuelcache_burned_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Burned Fuel Cache"] call OT_fnc_money;
            private _natoRes = server getVariable ["NATOresources", 0];
            server setVariable ["NATOresources", (_natoRes - 60) max 0, true];
        };
    },
    _params
]
