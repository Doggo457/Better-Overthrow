/*
 * BO mission: Prison Break
 *
 * Target = Town. Heavily-garrisoned NATO prison compound spawns
 * 400-700m from a NATO-controlled town. Layout (rotated by
 * _baseDir; all distances are radius from compound centre):
 *
 *                          (N = front)
 *                              |
 *                  [tower @45] | [tower @315]
 *                              |
 *               [HBarrier @0]  |  [HBarrier @0]
 *                              |
 *                       [HQ building]      <- _prisonPos
 *                       (prisoners + garrison share the interior;
 *                        prisoners are civilian = neutral to NATO)
 *                              |
 *               [HBarrier @180] | [HBarrier @180]
 *                              |
 *                          [HMG @ 180]
 *
 * Prisoners spawn INSIDE the HQ building (Land_Cargo_HQ_V3_F),
 * ACE-handcuffed, occupying ground-floor buildingPos slots. The
 * earlier sandbag-pen layout was deliberately removed: prisoners
 * now sit on filtered ground-floor cells of the HQ so they can't
 * fall through the upper deck (the Arma quirk where buildingPos
 * returns upper-level cells whose units phase through to terrain).
 * The buildingPos array is shuffled, then drained first by the
 * prisoner loop and then by the inner-garrison loop, so prisoners
 * and NATO never collide on the same cell. Garrison overflow goes
 * to a 10m perimeter ring around the HQ.
 *
 * Garrison composition:
 *   - 6 elite NATO inside/around the HQ (taskDefend, 15m radius)
 *   - 2 NATO inner garrison (same group; fills HQ interior overflow)
 *   - 2 NATO on outer perimeter sweep (separate group, taskPatrol
 *     at 50m, the user-requested outside patrol)
 *   - 1 HMG static + crew (separate AI group), covers the gate
 *
 * Win condition is the same shape as Save the Mayor:
 *   - Kill the captors (or sneak past them)
 *   - Walk up to each prisoner and ACE-release them individually
 *     (ACE Interact -> Release Captive). Nothing auto-uncuffs;
 *     killing the garrison does NOT free the prisoners on its own.
 *   - Escort at least one released prisoner 800m clear of the
 *     compound
 *   - Mission succeeds the instant a freed prisoner crosses the
 *     800m line
 *
 * Reward scales: $2500 per prisoner saved (i.e. alive when escort
 * completes), $7500 max. Compound + bodies persist 1hr via
 * BO_fnc_logMissionDebris.
 */

params ["_jobid", "_jobparams"];

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

// Find a safe spawn 400-700m from town. Force a 35m clearance so
// the compound has room without colliding into terrain features.
private _prisonPos = [];
for "_attempt" from 1 to 25 do {
    private _candidate = [_townPos, 400, 700, 35, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_candidate isEqualType [] && {(count _candidate) >= 2} && {(_candidate select 0) > 0}) exitWith {
        // findSafePos returns a 2D position [x, y]; setPosATL and
        // CBA_fnc_taskDefend both want a 3-element vector. Append
        // Z=0 so we don't trip "2 elements provided, 3 expected"
        // later.
        _prisonPos = [_candidate select 0, _candidate select 1, 0];
    };
};
if (_prisonPos isEqualTo []) exitWith { [] };

private _rewardPerPrisoner = 2500;
private _maxReward = 7500;
private _numPrisoners = 3;
private _escortDistance = 800;

private _title = format ["Prison Break near %1", _townName];
private _description = format [
    "NATO is holding %1 resistance prisoners ACE-cuffed inside a fortified HQ building near %2 -- perimeter walls, towers, HMG covering the gate, garrison sharing the interior. Clear the garrison (or sneak past it), then ACE-release each prisoner (Interact -> Release Captive) and escort at least one of them %3m clear of the compound.<br/><br/>Reward: $%4 per saved prisoner, $%5 max. Compound + bodies stay for an hour.",
    _numPrisoners, _townName, _escortDistance, _rewardPerPrisoner, _maxReward
];

private _params = [_jobid, _prisonPos, _numPrisoners, _rewardPerPrisoner, _escortDistance];

[
    [_title, _description],
    _prisonPos,
    {
        params ["_jobid", "_prisonPos", "_numPrisoners"];

        private _baseDir = random 360;
        private _props = [];

        // ---- 1) HQ building, the "barracks" visual anchor. ----
        // Decorative -- nobody spawns INSIDE this. Spawning into
        // buildingPos values has historically clipped units into
        // the floor on some maps; we sidestep the whole problem by
        // never using buildingPos for any unit.
        private _hq = createVehicle ["Land_Cargo_HQ_V3_F", _prisonPos, [], 0, "CAN_COLLIDE"];
        _hq setDir _baseDir;
        _hq setPosATL _prisonPos;
        _props pushBack _hq;

        // ---- 2) Patrol towers, front-flanking the HQ. ----
        // Empty (no AI tower garrison -- AI on a tower ladder is
        // unreliable). Towers are pure cover/visual.
        {
            private _towerPos = _prisonPos getPos [22, _baseDir + _x];
            private _t = createVehicle ["Land_Cargo_Patrol_V3_F", _towerPos, [], 0, "CAN_COLLIDE"];
            _t setPosATL _towerPos;
            _t setDir (_baseDir + _x + 180);
            _props pushBack _t;
        } forEach [45, 315];

        // ---- 3) HBarrier perimeter, 22m radius, 4 cardinals. ----
        {
            private _hbPos = _prisonPos getPos [22, _baseDir + _x];
            private _hb = OT_NATO_Barrier_Large createVehicle _hbPos;
            _hb setPosATL _hbPos;
            _hb setDir (_baseDir + _x + 90);
            _props pushBack _hb;
        } forEach [0, 90, 180, 270];

        // ---- 4) HMG covering the front gate, 16m south. ----
        private _hmgPos = _prisonPos getPos [16, _baseDir + 180];
        private _hmg = OT_NATO_HMG createVehicle _hmgPos;
        _hmg setPosATL _hmgPos;
        _hmg setDir (_baseDir + 180);
        _hmg setVariable ["BO_exempt", true, true];
        createVehicleCrew _hmg;
        { _x setVariable ["BO_exempt", true, true] } forEach (crew _hmg);

        // ---- 5) Prisoners inside the HQ building, ACE handcuffed. ----
        // Prisoners are CIVILIAN side and STAY civilian for the
        // entire mission. Civilians are neutral to every other side,
        // so no NATO unit -- even one that spawns nearby -- will
        // ever target them. NO transition to independent under any
        // circumstance (the previous joinSilent-into-player's-group
        // path moved them onto independent side mid-mission and a
        // stray NATO would then shoot them; remove it entirely).
        //
        // Placement: HQ's interior building positions filtered for
        // valid (non-origin) values AND filtered to GROUND FLOOR
        // ONLY. Land_Cargo_HQ_V3_F has an upper-deck level at +3m
        // above the floor; buildingPos returns positions on both
        // levels but a long-standing Arma quirk with this building
        // means units placed on the upper deck fall through to
        // terrain (appearing to stand "underneath" the building).
        // Filtering for Z within ~1.8m of the HQ's own ground level
        // keeps only the ground-floor cells, sidestepping that
        // quirk entirely.
        private _civGroup = createGroup [civilian, true];
        private _prisoners = [];
        private _bps = _hq buildingPos -1;
        _bps = _bps select { !(_x isEqualTo [0,0,0]) };
        private _hqGroundZ = (getPosATL _hq) select 2;
        _bps = _bps select { ((_x select 2) - _hqGroundZ) < 1.8 };
        // Shuffle once so prisoners take a random subset; NATO will
        // garrison whatever slots remain. deleteAt 0 in the prisoner
        // loop AND the garrison loop drains the same shared array,
        // so no two units can ever land on the same buildingPos.
        _bps = _bps call BIS_fnc_arrayShuffle;
        // BO_wasCuffed is what blocks the success check from auto-
        // firing on tick 1. Set it once at the prisoner level if ACE
        // is detected -- robust against any per-call silent failure.
        private _aceCuffsAvailable = !isNil "ace_captives_fnc_setHandcuffed";

        for "_p" from 1 to _numPrisoners do {
            private _spawnPos = if (_bps isNotEqualTo []) then {
                _bps deleteAt 0
            } else {
                // Fallback: spawn just outside HQ door area if the
                // building somehow has no ground-floor buildingPos.
                _prisonPos getPos [4, _baseDir + (60 * _p)]
            };
            private _u = _civGroup createUnit ["C_man_polo_1_F", _spawnPos, [], 0, "NONE"];
            // setPosATL anchors to the unit's OWN xy terrain; the +0.1
            // Z bump on top of the buildingPos Z lifts the unit
            // slightly above the floor mesh so models with a sub-floor
            // origin don't visually clip into the floor.
            _u setPosATL [(_spawnPos select 0), (_spawnPos select 1), (_spawnPos select 2) + 0.2];
            _u setDir (random 360);
            _u setVariable ["BO_exempt", true, true];
            removeAllWeapons _u;
            removeAllItems _u;
            _u disableAI "PATH";
            _u disableAI "MOVE";
            _u setCaptive true;
            if (_aceCuffsAvailable) then {
                [_u, true] call ace_captives_fnc_setHandcuffed;
            };
            _u setVariable ["BO_wasCuffed", _aceCuffsAvailable, true];
            _prisoners pushBack _u;
        };

        // ---- 7) Inner garrison. ----
        // The HMG crew is kept in their OWN group (created
        // automatically by createVehicleCrew above). DO NOT merge
        // them into the foot-soldier group: createVehicleCrew makes
        // the HMG gunner the group leader, and CBA_fnc_taskDefend
        // issues waypoints to the leader -- which would order the
        // gunner OFF the HMG to defend on foot, leaving the HMG
        // empty. Keep them separate; the "all NATO dead" check sums
        // across both groups + the outer patrol below.
        private _hmgGroup = group ((crew _hmg) param [0, objNull]);
        if (!isNull _hmgGroup) then {
            _hmgGroup setVariable ["VCM_TOUGHSQUAD", true, true];
            _hmgGroup setCombatMode "RED";
            _hmgGroup setBehaviour "COMBAT";
        };

        // Fresh foot-soldier group. First unit created becomes the
        // leader, so taskDefend's leader-targeted waypoints go to a
        // proper grunt who can move.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];

        private _poolElite = if (isNil "OT_NATO_Units_LevelTwo") then { [] } else { OT_NATO_Units_LevelTwo };
        if (_poolElite isEqualTo []) then {
            _poolElite = if (isNil "OT_NATO_Units_LevelOne") then { [] } else { OT_NATO_Units_LevelOne };
        };
        private _pool = if (isNil "OT_NATO_Units_LevelOne") then { [] } else { OT_NATO_Units_LevelOne };
        if (_pool isEqualTo []) then {
            _pool = [OT_NATO_Unit_TeamLeader];
        };

        // ACE-style garrison around the HQ within a 10m radius.
        //
        // ACE's Zeus Garrison module collects interior building
        // positions inside a radius and places one AI unit at each.
        // Any unit that doesn't get an interior slot falls back to
        // the perimeter ring. We mirror that here:
        //   1. `_bps` still has whatever HQ ground-floor slots the
        //      prisoner loop above did NOT consume -- those go to
        //      NATO first.
        //   2. Overflow goes to the 10m ring around the HQ,
        //      rejection-sampled against the HQ object position with
        //      a hard 8m floor so nobody clips into the floor mesh.
        // Prisoners are civilian (neutral to all sides) so NATO
        // sharing the HQ interior with them is safe.
        private _pickPerimeterPos = {
            private _pos = [0, 0, 0];
            for "_try" from 1 to 50 do {
                private _angle = random 360;
                private _candidate = _prisonPos getPos [10, _angle];
                if ((_candidate distance2D _hq) > 8) exitWith { _pos = _candidate };
            };
            if (_pos isEqualTo [0, 0, 0]) then {
                _pos = _prisonPos getPos [11, random 360];
            };
            _pos
        };

        // 6 elite defenders + 2 inner patrollers = 8 garrison units.
        private _garrisonCount = 8;
        for "_i" from 1 to _garrisonCount do {
            private _classPool = if (_i <= 6) then { _poolElite } else { _pool };
            private _u = _group createUnit [selectRandom _classPool, _prisonPos, [], 0, "NONE"];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_Prison"] call OT_fnc_initMilitary;

            if (_bps isNotEqualTo []) then {
                // Interior HQ slot left over from the prisoner loop.
                private _bp = _bps deleteAt 0;
                _u setPosATL [(_bp select 0), (_bp select 1), (_bp select 2) + 0.2];
                _u setUnitPos "MIDDLE";
                doStop _u;
                _u disableAI "PATH";
            } else {
                // Perimeter: 10m ring around the HQ.
                private _spawnPos = call _pickPerimeterPos;
                _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0.05];
            };
        };
        [_group, _prisonPos, 15] call CBA_fnc_taskDefend;

        // ---- 8) Small outside patrol (user-spec'd). ----
        // 2 NATO patrolling the wider perimeter, 30-50m out so the
        // player encounters them on the approach. Separate group;
        // counted in the "all NATO dead" sum.
        private _patrolGroup = createGroup [blufor, true];
        _patrolGroup setVariable ["VCM_TOUGHSQUAD", true, true];
        for "_i" from 1 to 2 do {
            private _spawnPos = _prisonPos getPos [30 + (random 20), random 360];
            private _u = _patrolGroup createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0.05];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_PrisonPatrol"] call OT_fnc_initMilitary;
        };
        [_patrolGroup, _prisonPos, 50, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_prison_props_%1",     _jobid], _props];
        missionNamespace setVariable [format ["BO_prison_hmg_%1",       _jobid], _hmg];
        missionNamespace setVariable [format ["BO_prison_hmggrp_%1",    _jobid], _hmgGroup];
        missionNamespace setVariable [format ["BO_prison_group_%1",     _jobid], _group];
        missionNamespace setVariable [format ["BO_prison_patrol_%1",    _jobid], _patrolGroup];
        missionNamespace setVariable [format ["BO_prison_civgrp_%1",    _jobid], _civGroup];
        missionNamespace setVariable [format ["BO_prison_prisoners_%1", _jobid], _prisoners];
        true
    },
    {
        // Fail when ALL prisoners are dead.
        params ["_jobid"];
        private _prisoners = missionNamespace getVariable [format ["BO_prison_prisoners_%1", _jobid], []];
        if (_prisoners isEqualTo []) exitWith { false };
        ({ alive _x } count _prisoners) isEqualTo 0
    },
    {
        params ["_jobid", "_prisonPos", "", "", "_escortDistance"];
        private _prisoners   = missionNamespace getVariable [format ["BO_prison_prisoners_%1", _jobid], []];
        if (_prisoners isEqualTo []) exitWith { false };

        // No auto-uncuff. Player must walk up to each prisoner and
        // use ACE Interact > Release Captive on them individually --
        // same as Save the Mayor.
        //
        // Per-tick: for each prisoner whose ACE_isHandcuffed has
        // transitioned to false (player just released them), wire
        // them up:
        //   - enable AI movement
        //   - clear captive flag (lets them move; civilian side
        //     keeps them neutral to everybody so they're never
        //     auto-killed)
        //   - doFollow the nearest player every tick. NO joinSilent
        //     and NO side change -- the user wants prisoners to
        //     stay civilian for the whole mission, full stop. Cross-
        //     side doFollow on civilians is what Save the Mayor uses
        //     and it works well enough for the player to lead them
        //     out (the player walking forward is what really drives
        //     the 800m escape check).
        {
            private _prisoner = _x;
            if (alive _prisoner
                && !(_prisoner getVariable ["ACE_isHandcuffed", false])
                && !(_prisoner getVariable ["BO_prisonerFreed", false])
            ) then {
                _prisoner enableAI "PATH";
                _prisoner enableAI "MOVE";
                _prisoner setUnitPos "AUTO";
                _prisoner setCaptive false;
                _prisoner setVariable ["BO_prisonerFreed", true, true];
            };
            if (alive _prisoner
                && (_prisoner getVariable ["BO_prisonerFreed", false])
            ) then {
                private _nearestPlayer = objNull;
                private _bestDist = 99999;
                {
                    if (alive _x) then {
                        private _d = _x distance _prisoner;
                        if (_d < _bestDist) then {
                            _bestDist = _d;
                            _nearestPlayer = _x;
                        };
                    };
                } forEach allPlayers;
                if (!isNull _nearestPlayer) then {
                    _prisoner doFollow _nearestPlayer;
                };
            };
        } forEach _prisoners;

        // ---- Success: at least one prisoner alive AND uncuffed AND
        //               escorted >_escortDistance from compound. ----
        // Identical win shape to Save the Mayor. The BO_wasCuffed
        // precondition guards against the ACE-not-loaded edge case
        // (no cuff was ever set -> every prisoner reads uncuffed on
        // tick 1 -> mission would otherwise auto-succeed).
        private _everCuffed = (_prisoners findIf { _x getVariable ["BO_wasCuffed", false] }) >= 0;
        if (!_everCuffed) exitWith { false };

        private _liveOnes = _prisoners select { alive _x };
        if (_liveOnes isEqualTo []) exitWith { false };

        private _escaped = _liveOnes findIf {
            !(_x getVariable ["ACE_isHandcuffed", false])
                && ((_x distance2D _prisonPos) > _escortDistance)
        };
        _escaped >= 0
    },
    {
        params ["_jobid", "", "", "_rewardPerPrisoner", "", "_wassuccess"];

        private _props       = missionNamespace getVariable [format ["BO_prison_props_%1",     _jobid], []];
        private _hmg         = missionNamespace getVariable [format ["BO_prison_hmg_%1",       _jobid], objNull];
        private _hmgGroup    = missionNamespace getVariable [format ["BO_prison_hmggrp_%1",    _jobid], grpNull];
        private _group       = missionNamespace getVariable [format ["BO_prison_group_%1",     _jobid], grpNull];
        private _patrolGroup = missionNamespace getVariable [format ["BO_prison_patrol_%1",    _jobid], grpNull];
        private _civGrp      = missionNamespace getVariable [format ["BO_prison_civgrp_%1",    _jobid], grpNull];
        private _prisoners   = missionNamespace getVariable [format ["BO_prison_prisoners_%1", _jobid], []];

        private _saved = { alive _x } count _prisoners;
        // Enforce documented $7500 cap so future tuning of numPrisoners or rewardPerPrisoner can't silently overpay.
        private _reward = (_saved * _rewardPerPrisoner) min 7500;

        // Hand the dead NATO + HMG over to the long-despawn registry
        // for looting. BO_exempt -> false so OT's standard GC can
        // re-take ownership of the bodies after the 1hr persistence.
        if (!isNull _group)       then { { _x setVariable ["BO_exempt", false, true] } forEach (units _group) };
        if (!isNull _hmgGroup)    then { { _x setVariable ["BO_exempt", false, true] } forEach (units _hmgGroup) };
        if (!isNull _patrolGroup) then { { _x setVariable ["BO_exempt", false, true] } forEach (units _patrolGroup) };
        [_props + [_hmg, _group, _hmgGroup, _patrolGroup]] call BO_fnc_logMissionDebris;

        // Make sure no surviving prisoner stays handcuffed.
        {
            if (alive _x) then {
                if (!isNil "ace_captives_fnc_setHandcuffed") then {
                    [_x, false] call ace_captives_fnc_setHandcuffed;
                };
                _x enableAI "PATH";
                _x enableAI "MOVE";
                _x setUnitPos "AUTO";
                _x setCaptive false;
                _x setVariable ["BO_exempt", false, true];
            };
        } forEach _prisoners;

        missionNamespace setVariable [format ["BO_prison_props_%1",     _jobid], nil];
        missionNamespace setVariable [format ["BO_prison_hmg_%1",       _jobid], nil];
        missionNamespace setVariable [format ["BO_prison_hmggrp_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_prison_group_%1",     _jobid], nil];
        missionNamespace setVariable [format ["BO_prison_patrol_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_prison_civgrp_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_prison_prisoners_%1", _jobid], nil];

        if (_wassuccess && _reward > 0) then {
            [_reward, format ["Prison Break (%1 saved)", _saved]] call OT_fnc_money;
        };
    },
    _params
]
