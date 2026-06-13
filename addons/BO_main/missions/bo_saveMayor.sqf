/*
 * BO mission: Save the Mayor (bandits)
 *
 * Bandits have grabbed the mayor and are holding him inside an
 * EXISTING town building (not a spawned cargo container). Player
 * breaches, kills the bandits, frees the mayor via ACE captives
 * interaction, and escorts him 800m clear of the town.
 *
 * Building selection uses real Arma 3 town houses found via
 * nearestObjects, filtered to ones with at least 3 interior
 * building positions on the GROUND FLOOR (Z within 1.8m of the
 * building's own anchor height). Real town buildings don't have
 * the upper-deck quirk that Land_Cargo_HQ_V3_F has -- the mayor
 * won't spawn on a phantom edge and fall to death.
 *
 * Garrison: ACE-style. Bandits are placed at remaining interior
 * positions of the chosen building plus any other house within
 * 10m -- exactly the pattern ACE3's Zeus Garrison module uses
 * internally (nearestObjects -> buildingPos -1 -> assign). Overflow
 * goes to the perimeter ring. Plus a small outside patrol of 2
 * bandits who taskPatrol the streets around the building.
 *
 * Bandits: O_Soldier_F (OPFOR military class) dressed in
 * OT_CRIM_Clothes so they LOOK like bandits but are recognised by
 * the engine as enemy combatants.
 *
 * Mayor: ACE captives setHandcuffed = true. Player frees via the
 * ACE interaction menu ("Release Captive"). Once freed, the mayor
 * follows the player.
 *
 * Bodies stay in the world for an hour via BO_fnc_logMissionDebris.
 * The town building itself is real terrain, not despawned.
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

// Find a town building with >=3 ground-floor positions. Search
// radius 250m around town centre, filter to houses whose interior
// positions on the ground floor (Z within 1.8m of their own anchor)
// number at least 3. That gives room for the mayor plus a couple of
// inside bandits.
// Viable house = bbox height >= 3m (excludes piers, walls, short
// infra) AND has >=3 ground-floor buildingPos slots that are not
// over water.
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

private _reward = 4000;
private _title = format ["Save the Mayor of %1", _townName];
private _description = format [
    "Bandits have grabbed the mayor of %1 and are holding him inside a building in town. Kill the bandits and free the mayor with ACE Interact (Release Captive), then escort him at least 800m clear of the town.<br/><br/>Reward: $%2 + standing in %1.",
    _townName, _reward
];

private _params = [_jobid, _house, _housePos, _townName, _reward];

[
    [_title, _description],
    _housePos,
    {
        params ["_jobid", "_house", "_housePos"];

        // ---- Collect ground-floor interior positions: this house
        //      PLUS any other house within 10m (ACE garrison radius).
        //      The combined pool is what bandits + the mayor garrison.
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

        // Shuffle for variety; mayor takes the first slot.
        _interiorPositions = _interiorPositions call BIS_fnc_arrayShuffle;
        if (_interiorPositions isEqualTo []) exitWith {};

        // ---- Mayor: civilian side, ACE handcuffed, first interior slot ----
        private _civGroup = createGroup [civilian, true];
        private _mayorPos = _interiorPositions deleteAt 0;
        private _mayor = _civGroup createUnit ["C_man_polo_5_F", _mayorPos, [], 0, "NONE"];
        // +0.2 Z bump prevents floor-mesh phasing on buildings whose
        // buildingPos Z sits a few cm below the visible floor.
        _mayor setPosATL [(_mayorPos select 0), (_mayorPos select 1), (_mayorPos select 2) + 0.2];
        _mayor setVariable ["BO_exempt", true, true];
        _mayor disableAI "PATH";
        _mayor disableAI "MOVE";
        _mayor setCaptive true;
        private _aceCuffsAvailable = !isNil "ace_captives_fnc_setHandcuffed";
        if (_aceCuffsAvailable) then {
            [_mayor, true] call ace_captives_fnc_setHandcuffed;
        };
        _mayor setVariable ["BO_wasCuffed", _aceCuffsAvailable, true];

        // ---- Bandits: OPFOR military class + criminal uniform ----
        private _banditGroup = createGroup [east, true];
        _banditGroup setVariable ["VCM_TOUGHSQUAD", true, true];
        _banditGroup setBehaviour "AWARE";
        _banditGroup setCombatMode "RED";

        // ACE garrison: fill remaining interior positions, overflow
        // goes to the 10m perimeter ring.
        private _numBandits = 6;
        private _interiorSlotsLeft = count _interiorPositions;

        for "_i" from 1 to _numBandits do {
            private _u = _banditGroup createUnit ["O_Soldier_F", _housePos, [], 0, "NONE"];
            _u setVariable ["BO_exempt", true, true];
            _u setCaptive false;
            _u setBehaviour "AWARE";
            _u setCombatMode "RED";

            removeAllWeapons _u;
            removeUniform _u;
            removeHeadgear _u;
            removeGoggles _u;
            removeBackpackGlobal _u;
            removeAllAssignedItems _u;
            removeAllItemsWithMagazines _u;

            _u forceAddUniform (selectRandom OT_CRIM_Clothes);
            _u addGoggles (selectRandom OT_CRIM_Goggles);
            private _wpn = selectRandom OT_CRIM_Weapons;
            _u addWeaponGlobal _wpn;
            private _mags = (getArray (configFile >> "CfgWeapons" >> _wpn >> "magazines"));
            if (_mags isNotEqualTo []) then {
                for "_m" from 1 to 4 do { _u addMagazineGlobal (selectRandom _mags) };
                _u selectWeapon _wpn;
            };

            // OT damage handlers (kill credit / rep)
            _u addEventHandler ["HandleDamage", {
                private _src = _this select 3;
                if (captive _src) then {
                    if (!isNull objectParent _src || (_src call OT_fnc_unitSeenNATO)) then {
                        _src setCaptive false;
                    };
                };
            }];
            _u addEventHandler ["Dammaged", OT_fnc_EnemyDamagedHandler];

            if (_i <= _interiorSlotsLeft) then {
                // Garrison inside
                private _bp = _interiorPositions deleteAt 0;
                _u setPosATL [(_bp select 0), (_bp select 1), (_bp select 2) + 0.2];
                _u setUnitPos "MIDDLE";
                doStop _u;
                _u disableAI "PATH";
            } else {
                // Overflow: perimeter ring 10m around the building
                private _outPos = _housePos getPos [10, random 360];
                _u setPosATL [_outPos select 0, _outPos select 1, 0];
            };
        };

        // ---- Small outside patrol: 2 bandits roaming the streets ----
        private _patrolGroup = createGroup [east, true];
        _patrolGroup setVariable ["VCM_TOUGHSQUAD", true, true];
        _patrolGroup setBehaviour "AWARE";
        _patrolGroup setCombatMode "RED";

        for "_i" from 1 to 2 do {
            private _spawnPos = _housePos getPos [25 + (random 10), random 360];
            private _u = _patrolGroup createUnit ["O_Soldier_F", _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            _u setCaptive false;

            removeAllWeapons _u;
            removeUniform _u;
            removeHeadgear _u;
            removeGoggles _u;
            removeBackpackGlobal _u;
            removeAllAssignedItems _u;
            removeAllItemsWithMagazines _u;
            _u forceAddUniform (selectRandom OT_CRIM_Clothes);
            _u addGoggles (selectRandom OT_CRIM_Goggles);
            private _wpn = selectRandom OT_CRIM_Weapons;
            _u addWeaponGlobal _wpn;
            private _mags = (getArray (configFile >> "CfgWeapons" >> _wpn >> "magazines"));
            if (_mags isNotEqualTo []) then {
                for "_m" from 1 to 4 do { _u addMagazineGlobal (selectRandom _mags) };
                _u selectWeapon _wpn;
            };

            _u addEventHandler ["HandleDamage", {
                private _src = _this select 3;
                if (captive _src) then {
                    if (!isNull objectParent _src || (_src call OT_fnc_unitSeenNATO)) then {
                        _src setCaptive false;
                    };
                };
            }];
            _u addEventHandler ["Dammaged", OT_fnc_EnemyDamagedHandler];
        };
        [_patrolGroup, _housePos, 35, 4] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_mayor_npc_%1",     _jobid], _mayor];
        missionNamespace setVariable [format ["BO_mayor_civgrp_%1",  _jobid], _civGroup];
        missionNamespace setVariable [format ["BO_mayor_bandits_%1", _jobid], _banditGroup];
        missionNamespace setVariable [format ["BO_mayor_patrol_%1",  _jobid], _patrolGroup];
        missionNamespace setVariable [format ["BO_mayor_house_%1",   _jobid], _house];
        true
    },
    {
        params ["_jobid"];
        private _mayor = missionNamespace getVariable [format ["BO_mayor_npc_%1", _jobid], objNull];
        isNull _mayor || { !alive _mayor }
    },
    {
        params ["_jobid", "", "_housePos"];
        private _mayor = missionNamespace getVariable [format ["BO_mayor_npc_%1", _jobid], objNull];
        if (isNull _mayor) exitWith { false };

        // Once the player ACE-releases the mayor, enable AI and have
        // him follow the nearest player.
        private _isHandcuffed = _mayor getVariable ["ACE_isHandcuffed", false];
        if (!_isHandcuffed && !(_mayor getVariable ["BO_mayorFreed", false])) then {
            _mayor enableAI "PATH";
            _mayor enableAI "MOVE";
            _mayor setUnitPos "AUTO";
            _mayor setCaptive false;
            _mayor setVariable ["BO_mayorFreed", true, true];
        };
        if (!_isHandcuffed) then {
            private _nearestPlayer = objNull;
            private _bestDist = 99999;
            {
                if (alive _x) then {
                    private _d = _x distance _mayor;
                    if (_d < _bestDist) then { _bestDist = _d; _nearestPlayer = _x };
                };
            } forEach allPlayers;
            if (!isNull _nearestPlayer) then { _mayor doFollow _nearestPlayer };
        };

        // BO_wasCuffed precondition blocks the ACE-not-loaded vacuous-
        // success path (mayor never gets cuffed -> reads as uncuffed
        // on tick 1 -> mission would auto-succeed).
        private _wasCuffed = _mayor getVariable ["BO_wasCuffed", false];
        if (!_wasCuffed) exitWith { false };

        // Success: mayor alive AND uncuffed AND 800m+ from the house.
        (alive _mayor) && (!_isHandcuffed) && ((_mayor distance2D _housePos) > 800)
    },
    {
        params ["_jobid", "", "", "_townName", "_reward", "_wassuccess"];

        private _mayor   = missionNamespace getVariable [format ["BO_mayor_npc_%1",     _jobid], objNull];
        private _civGrp  = missionNamespace getVariable [format ["BO_mayor_civgrp_%1",  _jobid], grpNull];
        private _bandits = missionNamespace getVariable [format ["BO_mayor_bandits_%1", _jobid], grpNull];
        private _patrol  = missionNamespace getVariable [format ["BO_mayor_patrol_%1",  _jobid], grpNull];

        if (!isNull _bandits) then { { _x setVariable ["BO_exempt", false, true] } forEach (units _bandits) };
        if (!isNull _patrol)  then { { _x setVariable ["BO_exempt", false, true] } forEach (units _patrol) };
        if (!isNull _mayor && alive _mayor) then {
            _mayor enableAI "PATH";
            _mayor enableAI "MOVE";
            _mayor setUnitPos "AUTO";
            _mayor setCaptive false;
            if (!isNil "ace_captives_fnc_setHandcuffed") then {
                [_mayor, false] call ace_captives_fnc_setHandcuffed;
            };
            _mayor setVariable ["BO_exempt", false, true];
        };

        // No HQ container to despawn -- the house is a real
        // map-resident building. Just register the bandit bodies
        // for the long-despawn registry so they stay an hour.
        [[_bandits, _patrol]] call BO_fnc_logMissionDebris;
        if (!isNull _civGrp) then { deleteGroup _civGrp };

        missionNamespace setVariable [format ["BO_mayor_npc_%1",     _jobid], nil];
        missionNamespace setVariable [format ["BO_mayor_civgrp_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_mayor_bandits_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_mayor_patrol_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_mayor_house_%1",   _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Saved the Mayor"] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                [_townName, 25, format ["Saved the mayor of %1", _townName]] call OT_fnc_support;
            };
        };
    },
    _params
]
