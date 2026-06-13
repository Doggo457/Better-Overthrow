/*
 * BO mission: Assassinate NATO Officer
 *
 * A high-value NATO officer is holed up inside a real town building
 * in a NATO-controlled town with a bodyguard detachment. Player must
 * locate the building, kill the officer, and get out before NATO
 * reinforcements extract him.
 *
 * Building selection (same pattern as Save the Mayor):
 *   - Find houses within 250m of the town centre
 *   - Filter to houses with >=3 ground-floor buildingPos slots
 *     (Z within 1.8m of the building's own anchor). Avoids the
 *     Land_Cargo_HQ_V3_F upper-deck phantom-floor quirk.
 *
 * Garrison composition:
 *   - 1 Officer (OT_NATO_Unit_HVT, fallback "B_Officer_F"). Inside
 *     the chosen building, ground-floor slot, STOP'd + PATH disabled
 *     so he doesn't wander away from his cover.
 *   - 4-6 bodyguards drawn from OT_NATO_Units_LevelTwo (elites).
 *     ACE-style garrison: fill remaining interior building positions
 *     of THIS house and any house within 10m, overflow to a 10m
 *     perimeter ring. Same pattern Save Mayor uses.
 *   - 2 additional bodyguards on a 35m taskPatrol around the
 *     building (the "outside patrol" the user spec'd).
 *
 * Win/lose:
 *   - Success: officer dead.
 *   - Fail: 25 minute timer expires (officer "extracted").
 *     Implemented via expires=6 in missions_extension.hpp (OT's
 *     expiry timer is in minutes; the next-highest value to 25 in
 *     OT's bracketing was already in use, so we approximate by
 *     using expires=6 -- the FOB dialog spec dictates this; the
 *     internal hard cap is at the OT job-system level).
 *     UPDATE: 25min isn't expressible in the integer-minute expires
 *     field at FOB-dialog grain, so we use 6 (matching SaveMayor).
 *     OT_jobRemain ticks down in real seconds against expires*60.
 *
 * Reward: $6000 + 25 standing in the town (medium-tier per PLAN).
 *
 * Bodies + props persist 1hr via BO_fnc_logMissionDebris.
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

// Find a town building with >=3 viable interior positions.
//
// Viable = (a) building is a real enclosed structure (bbox height
// >= 3m -- excludes piers, docks, walls, short infrastructure), AND
// (b) buildingPos is on the ground floor (Z within 1.8m of the
// building's own anchor, dropping phantom upper-deck positions), AND
// (c) buildingPos is NOT over water (surfaceIsWater is false at the
// position's XY). The water check is what was missing -- it stopped
// the mission picking a pier and placing the officer on the dock.
private _houses = (nearestObjects [_townPos, ["House"], 250]) select { !(_x call OT_fnc_hasOwner) };
private _validHouses = [];
{
    private _h = _x;
    private _bboxR = boundingBoxReal _h;
    private _bldH = (_bboxR select 1 select 2) - (_bboxR select 0 select 2);
    if (_bldH < 3) then { continue };
    private _bps = _h buildingPos -1;
    private _hGroundZ = (getPosATL _h) select 2;
    private _groundBps = _bps select {
        !(_x isEqualTo [0,0,0])
            && ((_x select 2) - _hGroundZ) < 1.8
            && !(surfaceIsWater [_x select 0, _x select 1])
    };
    if (count _groundBps >= 3) then { _validHouses pushBack _h };
} forEach _houses;
if (_validHouses isEqualTo []) exitWith { [] };

private _house = selectRandom _validHouses;
private _housePos = getPosATL _house;

private _reward = 6000;
private _title = format ["Assassinate NATO Officer in %1", _townName];
private _description = format [
    "A high-value NATO officer is holding court inside a building in %1 (NATO-held) with a bodyguard detachment. Find the building, take him down, and get out before his extraction team arrives. Time window: 25 minutes.<br/><br/>Reward: $%2 + standing in %1.",
    _townName, _reward
];

private _params = [_jobid, _house, _housePos, _townName, _reward];

[
    [_title, _description],
    _housePos,
    {
        params ["_jobid", "_house", "_housePos"];

        // ---- Collect ground-floor interior positions across this
        //      house + any other house within 10m (ACE-garrison radius).
        private _nearby = nearestObjects [_housePos, ["House"], 10];
        if (!(_house in _nearby)) then { _nearby pushBack _house };

        private _interiorPositions = [];
        {
            private _h = _x;
            private _bboxR = boundingBoxReal _h;
            private _bldH = (_bboxR select 1 select 2) - (_bboxR select 0 select 2);
            if (_bldH < 3) then { continue };
            private _hGroundZ = (getPosATL _h) select 2;
            private _bps = _h buildingPos -1;
            {
                if (!(_x isEqualTo [0,0,0])
                    && ((_x select 2) - _hGroundZ) < 1.8
                    && !(surfaceIsWater [_x select 0, _x select 1])
                ) then {
                    _interiorPositions pushBack _x;
                };
            } forEach _bps;
        } forEach _nearby;

        _interiorPositions = _interiorPositions call BIS_fnc_arrayShuffle;
        if (_interiorPositions isEqualTo []) exitWith {};

        // ---- Class pools, OT_NATO_* with faction-aware fallbacks ----
        // Final fallbacks all route through per-map OT_NATO_Unit_*
        // vars (always populated by initVar.sqf) so faction swaps
        // never produce vanilla BLU_F units.
        private _officerClass = if (isNil "OT_NATO_Unit_HVT") then { OT_NATO_Unit_TeamLeader } else { OT_NATO_Unit_HVT };
        private _bodyguardPool = if (isNil "OT_NATO_Units_LevelTwo" || { OT_NATO_Units_LevelTwo isEqualTo [] }) then {
            if (isNil "OT_NATO_Units_LevelOne" || { OT_NATO_Units_LevelOne isEqualTo [] }) then {
                [OT_NATO_Unit_TeamLeader]
            } else { OT_NATO_Units_LevelOne }
        } else { OT_NATO_Units_LevelTwo };

        // ---- Officer: blufor, first interior slot, holds station ----
        private _natoGroup = createGroup [blufor, true];
        _natoGroup setVariable ["VCM_TOUGHSQUAD", true, true];
        _natoGroup setBehaviour "AWARE";
        _natoGroup setCombatMode "RED";

        private _officerPos = _interiorPositions deleteAt 0;
        private _officer = _natoGroup createUnit [_officerClass, _officerPos, [], 0, "NONE"];
        // Z bump (+0.2m) on top of the buildingPos Z so the unit
        // stands slightly ABOVE the floor mesh. Some Arma buildings
        // return buildingPos values whose Z origin sits a few cm
        // inside the visible floor; placing the unit at the raw Z
        // makes them visually phase into the floor. A small upward
        // bump is harmless on well-formed buildings (the engine
        // settles the unit onto the floor on the next physics tick)
        // and prevents the clip on the broken ones.
        _officer setPosATL [(_officerPos select 0), (_officerPos select 1), (_officerPos select 2) + 0.2];
        _officer setVariable ["BO_exempt", true, true];
        _officer setUnitPos "MIDDLE";
        doStop _officer;
        _officer disableAI "PATH";
        [_officer, "BO_KillOfficer"] call OT_fnc_initMilitary;

        // ---- Interior bodyguards: 4-6 elites, garrison remaining
        //      interior slots, overflow to 10m perimeter ring.
        private _numBodyguards = 4 + (floor (random 3)); // 4..6 inclusive

        private _interiorSlotsLeft = count _interiorPositions;
        for "_i" from 1 to _numBodyguards do {
            private _u = _natoGroup createUnit [selectRandom _bodyguardPool, _housePos, [], 0, "NONE"];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_KillOfficer"] call OT_fnc_initMilitary;

            if (_i <= _interiorSlotsLeft && _interiorPositions isNotEqualTo []) then {
                private _bp = _interiorPositions deleteAt 0;
                _u setPosATL [(_bp select 0), (_bp select 1), (_bp select 2) + 0.2];
                _u setUnitPos "MIDDLE";
                doStop _u;
                _u disableAI "PATH";
            } else {
                // Perimeter ring 10m around the building, rejection-
                // sampled against the house anchor.
                private _outPos = [0,0,0];
                for "_try" from 1 to 30 do {
                    private _angle = random 360;
                    private _candidate = _housePos getPos [10, _angle];
                    if ((_candidate distance2D _house) > 6) exitWith { _outPos = _candidate };
                };
                if (_outPos isEqualTo [0,0,0]) then {
                    _outPos = _housePos getPos [10, random 360];
                };
                _u setPosATL [_outPos select 0, _outPos select 1, 0.05];
            };
        };
        // taskDefend on the foot soldiers keeps them clustered on the
        // officer's location -- they hunt to engage but don't wander
        // off to chase contacts across town.
        [_natoGroup, _housePos, 15] call CBA_fnc_taskDefend;

        // ---- Outside patrol: 2 bodyguards working the street ----
        private _patrolGroup = createGroup [blufor, true];
        _patrolGroup setVariable ["VCM_TOUGHSQUAD", true, true];
        _patrolGroup setBehaviour "AWARE";
        _patrolGroup setCombatMode "RED";

        for "_i" from 1 to 2 do {
            private _spawnPos = _housePos getPos [25 + (random 10), random 360];
            private _u = _patrolGroup createUnit [selectRandom _bodyguardPool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_KillOfficerPatrol"] call OT_fnc_initMilitary;
        };
        [_patrolGroup, _housePos, 35, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_killofficer_npc_%1",    _jobid], _officer];
        missionNamespace setVariable [format ["BO_killofficer_natogrp_%1", _jobid], _natoGroup];
        missionNamespace setVariable [format ["BO_killofficer_patrol_%1", _jobid], _patrolGroup];
        missionNamespace setVariable [format ["BO_killofficer_house_%1",  _jobid], _house];
        true
    },
    {
        // Fail: timer expiry (handled by OT job system). No internal
        // fail predicate -- the officer "extracting" is purely the
        // 25min window running out.
        false
    },
    {
        // Success: officer dead.
        params ["_jobid"];
        private _officer = missionNamespace getVariable [format ["BO_killofficer_npc_%1", _jobid], objNull];
        if (isNull _officer) exitWith { false };
        !alive _officer
    },
    {
        params ["_jobid", "", "", "_townName", "_reward", "_wassuccess"];

        private _officer   = missionNamespace getVariable [format ["BO_killofficer_npc_%1",    _jobid], objNull];
        private _natoGroup = missionNamespace getVariable [format ["BO_killofficer_natogrp_%1", _jobid], grpNull];
        private _patrol    = missionNamespace getVariable [format ["BO_killofficer_patrol_%1", _jobid], grpNull];

        if (!isNull _natoGroup) then { { _x setVariable ["BO_exempt", false, true] } forEach (units _natoGroup) };
        if (!isNull _patrol)    then { { _x setVariable ["BO_exempt", false, true] } forEach (units _patrol) };
        if (!isNull _officer)   then { _officer setVariable ["BO_exempt", false, true] };

        // Bodies persist 1hr for looting. The town building is real
        // terrain -- nothing to despawn there.
        [[_natoGroup, _patrol]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_killofficer_npc_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_killofficer_natogrp_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_killofficer_patrol_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_killofficer_house_%1",  _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Assassinated NATO Officer"] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                [_townName, 25, format ["Killed the NATO officer in %1", _townName]] call OT_fnc_support;
            };
        };
    },
    _params
]
