/*
 * BO mission: Protect a Defector
 *
 * Target = Town. A NATO informant wants to defect; he's holed up in
 * a house inside a NATO-controlled town. Player has to reach him,
 * and once any player gets within 50m, NATO finds out and sends
 * one wave from the nearest NATO base to kill him.
 *
 * Trigger: any player within 50m of the defector. Until that point
 * the defector just stands in the house; nothing else happens.
 *
 * Wave delivery (one wave, 12 troops):
 *   - 50/50 chance ground vs air.
 *   - GROUND: NATO transport truck from OT_NATO_Vehicle_Transport
 *     spawns at the nearest NATO objective/base, loaded with
 *     however many troops fit (capped at 12).
 *   - AIR: B_Heli_Transport_03_F (Huron, 12-cargo) spawns at the
 *     nearest base AT 150m altitude with engines already on and
 *     forward velocity. Flies to defector area and ejects all 12
 *     paratroopers. Heli RTBs after the drop.
 *
 * Success: defector alive AND (all attackers dead OR 15 minutes
 * elapsed since the wave triggered).
 *
 * All vehicles + bodies persist 1hr via BO_fnc_logMissionDebris.
 */

params ["_jobid", "_jobparams"];

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

// Defector goes inside a house in the town centre. Pick any house
// in a 200m radius that has at least one interior building position,
// then select a random interior pos. Random pick (rather than
// always pos 0) avoids houses whose first index is bogus and gives
// repeat plays a different "hide" spot in the same town.
// Viable house: bbox height >= 3m (excludes piers/walls/short
// infra), and at least one buildingPos that is (a) non-zero,
// (b) ground floor (within 1.8m of building anchor Z), and
// (c) not over water. Multiple buildings may pass -- iterate until
// we find one with valid positions, otherwise the mission can't
// place the defector safely.
private _houses = (nearestObjects [_townPos, ["House"], 200]) select { !(_x call OT_fnc_hasOwner) };
private _picked = [];
{
    private _h = _x;
    private _bboxR = boundingBoxReal _h;
    private _bldH = (_bboxR select 1 select 2) - (_bboxR select 0 select 2);
    if (_bldH < 3) then { continue };
    private _hGroundZ = (getPosATL _h) select 2;
    private _bps = (_h buildingPos -1) select {
        !(_x isEqualTo [0,0,0])
            && ((_x select 2) - _hGroundZ) < 1.8
            && !(surfaceIsWater [_x select 0, _x select 1])
    };
    if (count _bps > 0) then { _picked pushBack [_h, _bps] };
} forEach _houses;
if (_picked isEqualTo []) exitWith { [] };
private _chosen = selectRandom _picked;
private _house = _chosen select 0;
private _bps = _chosen select 1;
private _bp = selectRandom _bps;

// Pick the nearest NATO-controlled base/objective for the wave
// origin. Must be at least 300m from the defector -- otherwise the
// "convoy travels to the defender" premise collapses (truck would
// spawn essentially on top of the defender and the arrival check
// would fire on the first tick). Fall back to other NATO towns if
// no live NATO objectives qualify.
private _MIN_ORIGIN_DIST = 300;
private _natoBases = (if (isNil "OT_objectiveData") then { [] } else { OT_objectiveData })
    select { !((_x select 1) in _abandoned) && ((_x select 0) distance2D _bp > _MIN_ORIGIN_DIST) };
if (_natoBases isEqualTo []) then {
    _natoBases = _natoTowns select {
        ((_x select 1) isNotEqualTo _townName)
            && (((_x select 0) distance2D _bp) > _MIN_ORIGIN_DIST)
    };
};
if (_natoBases isEqualTo []) exitWith { [] };
private _natoBaseSorted = [_natoBases, [], { (_x select 0) distance2D _bp }, "ASCEND"] call BIS_fnc_sortBy;
private _wavePos = (_natoBaseSorted select 0) select 0;
private _waveOriginName = (_natoBaseSorted select 0) select 1;

private _reward = 6000;
private _defenseDurationSec = 900;  // 15 min cap
private _triggerRadius = 50;        // player-near radius that triggers the wave
private _waveSize = 12;              // troops in the wave

private _title = format ["Protect Defector at %1", _townName];
private _description = format [
    "A NATO informant is hiding in a house in %1. Get within 50m of him -- NATO will find out and send a squad from %2 to silence him. Keep him alive for 15 minutes or until you've wiped the squad.<br/><br/>Reward: $%3",
    _townName, _waveOriginName, _reward
];

private _params = [_jobid, _bp, _wavePos, _triggerRadius, _waveSize, _defenseDurationSec, _reward];

[
    [_title, _description],
    _bp,
    {
        params ["_jobid", "_bp"];

        // Defector on INDEPENDENT side -- friendly to players (also
        // independent in OT), but flagged hostile to NATO (blufor),
        // so the wave will actually engage him. Civilian + captive
        // would mean NATO never attacks, defeating the whole
        // "silence him" premise. We strip his loadout so he doesn't
        // fight back, and disableAI "PATH" so he stays in the house.
        private _civGrp = createGroup [independent, true];
        private _defector = _civGrp createUnit ["C_man_polo_2_F", _bp, [], 0, "NONE"];
        // +0.2 Z bump avoids floor-mesh phasing on buildings whose
        // buildingPos Z sits slightly below the visible floor.
        _defector setPosATL [(_bp select 0), (_bp select 1), (_bp select 2) + 0.2];
        _defector setVariable ["BO_exempt", true, true];
        removeAllWeapons _defector;
        removeAllItems _defector;
        _defector disableAI "PATH";
        _defector disableAI "MOVE";
        _defector setUnitPos "MIDDLE";

        missionNamespace setVariable [format ["BO_def_npc_%1",       _jobid], _defector];
        missionNamespace setVariable [format ["BO_def_civgrp_%1",    _jobid], _civGrp];
        missionNamespace setVariable [format ["BO_def_triggered_%1", _jobid], false];
        missionNamespace setVariable [format ["BO_def_waveGroup_%1", _jobid], grpNull];
        missionNamespace setVariable [format ["BO_def_waveVeh_%1",   _jobid], objNull];
        missionNamespace setVariable [format ["BO_def_defStart_%1",  _jobid], 0];
        true
    },
    {
        params ["_jobid"];
        private _defector = missionNamespace getVariable [format ["BO_def_npc_%1", _jobid], objNull];
        isNull _defector || { !alive _defector }
    },
    {
        params ["_jobid", "_bp", "_wavePos", "_triggerRadius", "_waveSize", "_defenseDurationSec"];
        private _defector = missionNamespace getVariable [format ["BO_def_npc_%1", _jobid], objNull];
        if (isNull _defector) exitWith { false };

        private _triggered = missionNamespace getVariable [format ["BO_def_triggered_%1", _jobid], false];

        // ---- Phase 1: wait for player to get within 50m of defector ----
        if (!_triggered) then {
            private _playerNear = false;
            {
                if (alive _x && {_x distance _defector < _triggerRadius}) exitWith { _playerNear = true };
            } forEach allPlayers;
            if (!_playerNear) exitWith {};

            // Trigger the wave.
            missionNamespace setVariable [format ["BO_def_triggered_%1", _jobid], true];
            missionNamespace setVariable [format ["BO_def_defStart_%1",  _jobid], diag_tickTime];

            // Defensive: OT_NATO_Units_LevelOne could be nil if the
            // NATO factions init hasn't run yet (very fresh save).
            // Fall back to the team-leader class which is set early.
            private _pool = if (isNil "OT_NATO_Units_LevelOne") then { [] } else { OT_NATO_Units_LevelOne };
            if (_pool isEqualTo []) then {
                _pool = [OT_NATO_Unit_TeamLeader];
            };

            private _waveGroup = createGroup [blufor, true];
            _waveGroup setVariable ["VCM_TOUGHSQUAD", true, true];
            _waveGroup setBehaviour "COMBAT";
            _waveGroup setCombatMode "RED";

            // Two-group structure:
            //   _waveGroup  -- the 12 paratroopers (engages defender).
            //                  This group's SAD waypoint at _bp is
            //                  what makes them search the area once
            //                  they're on foot. Always blufor.
            //   _vehGroup   -- the transport's pilot/driver group
            //                  (separate, created by createVehicleCrew).
            //                  Drives/flies to the drop zone, then
            //                  drops the troops off and disengages.
            //
            // Critical: do NOT merge the two groups. If paratroopers
            // share the truck driver's group, the SAD waypoint queues
            // for the driver, who then drives to the SAD point with
            // the troops still belted in -- AI does not reliably
            // dismount on SAD arrival. Keeping them split + scripting
            // the dismount explicitly avoids that failure mode.

            // 50/50 ground convoy or paradrop.
            if ((random 1) < 0.5) then {
                // -- GROUND TRUCK from nearest NATO base --
                private _truckPool = OT_NATO_Vehicle_Transport;
                // Faction-aware fallback to the per-map Transport_Light
                // class. The previous TROPIC vanilla literal was Tanoa-
                // only and broke createVehicle on every other map; the
                // current fallback stays on whatever faction the player
                // selected.
                if (isNil "_truckPool" || { _truckPool isEqualTo [] }) then { _truckPool = [OT_NATO_Vehicle_Transport_Light] };
                private _truckClass = selectRandom _truckPool;
                private _veh = _truckClass createVehicle _wavePos;
                _veh setPosATL _wavePos;
                _veh setDir (_wavePos getDir _bp);
                _veh setVariable ["BO_exempt", true, true];
                createVehicleCrew _veh;
                { _x setVariable ["BO_exempt", true, true] } forEach (crew _veh);

                private _vehGroup = group driver _veh;

                // Cap troop count to the truck's cargo capacity.
                // Pure config read -- works for any transport class
                // in OT_NATO_Vehicle_Transport across all 4 maps.
                private _cap = getNumber (configFile >> "CfgVehicles" >> _truckClass >> "transportSoldier");
                if (_cap < 1) then { _cap = _waveSize };
                _cap = _cap min _waveSize;
                for "_i" from 1 to _cap do {
                    private _u = _waveGroup createUnit [selectRandom _pool, _wavePos getPos [random 6, random 360], [], 0, "NONE"];
                    _u setVariable ["BO_exempt", true, true];
                    [_u, "BO_DefectorAttack"] call OT_fnc_initMilitary;
                    _u assignAsCargo _veh;
                    _u moveInCargo _veh;
                };

                // Drive the truck to a dropoff point ~40m short of the
                // defender, so the driver doesn't try to park inside
                // the house. On arrival, force-eject every cargo
                // passenger so they actually get out and engage; SAD
                // alone is unreliable for dismount.
                private _dropoff = _bp getPos [40, _bp getDir _wavePos];
                private _driveWp = _vehGroup addWaypoint [_dropoff, 10];
                _driveWp setWaypointType "MOVE";
                _driveWp setWaypointSpeed "FULL";
                _driveWp setWaypointBehaviour "AWARE";

                [_veh, _wavePos, _bp, _waveGroup, _jobid] spawn {
                    params ["_veh", "_originPos", "_defenderPos", "_squad", "_jobid"];
                    // Step 1: wait until the truck has actually moved at
                    // least 100m from its spawn. Defense in depth on top
                    // of the mission-selection >300m guard: if the
                    // origin is somehow still close, we still won't
                    // disembark until the truck is genuinely en route.
                    // Also bail if the mission has already ended (the
                    // waveGroup namespace var gets cleared in onEnd).
                    private _moveDeadline = diag_tickTime + 300;
                    waitUntil {
                        sleep 1;
                        (!alive _veh)
                            || ((_veh distance2D _originPos) > 100)
                            || (diag_tickTime > _moveDeadline)
                            || (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] })
                    };
                    if (!alive _veh) exitWith {};
                    if (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] }) exitWith {};
                    // Step 2: wait for arrival, truck death, or crew
                    // wipe -- with a 10-minute deadline. If the truck
                    // gets terrain-blocked and can't actually reach
                    // the dropoff, force-eject in place rather than
                    // leak this spawn for the rest of the mission.
                    private _arriveDeadline = diag_tickTime + 600;
                    waitUntil {
                        sleep 2;
                        (!alive _veh)
                            || ((_veh distance2D _defenderPos) < 70)
                            || (({alive _x} count (crew _veh)) isEqualTo 0)
                            || (diag_tickTime > _arriveDeadline)
                            || (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] })
                    };
                    if (!alive _veh) exitWith {};
                    if (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] }) exitWith {};
                    // Force every cargo passenger out and onto foot.
                    // Works at the dropoff OR wherever the truck is
                    // when the deadline expires.
                    {
                        if (alive _x && (vehicle _x) isEqualTo _veh) then {
                            unassignVehicle _x;
                            _x leaveVehicle _veh;
                            _x action ["EJECT", _veh];
                        };
                    } forEach (units _squad);
                };

                missionNamespace setVariable [format ["BO_def_waveVeh_%1",   _jobid], _veh];
            } else {
                // -- PARADROP from nearest NATO base --
                // Heli spawns IN THE AIR at 150m AGL with engines on.
                // createVehicle "FLY" mode starts the vehicle at flight
                // altitude with the velocity needed to stay airborne.
                // We also call setVelocityModelSpace as a hint, but the
                // engine's flight AI takes over within ~1-2 frames and
                // computes its own velocity -- the hint is mostly
                // cosmetic. What MATTERS is that the heli is airborne
                // from frame 1 with no takeoff stutter, and the AI
                // pilot navigates the MOVE waypoint at full speed.
                //
                // Huron (B_Heli_Transport_03_F) has 18 cargo seats,
                // so the 12 paratroopers fit comfortably. We still
                // cap via config to keep the code map-portable.
                // Prefer the map's configured large air-transport (varies by terrain pack); fall back to Huron only if the global isn't defined.
                // Defensive fallback uses the per-map AirTransport array's first entry --
                // every shipped map populates that array, so faction swaps stay correct.
                private _heliClass = if (isNil "OT_NATO_Vehicle_AirTransport_Large") then {
                    (OT_NATO_Vehicle_AirTransport param [0, ""])
                } else { OT_NATO_Vehicle_AirTransport_Large };
                private _heliSpawn = [_wavePos select 0, _wavePos select 1, 150];
                private _heli = createVehicle [_heliClass, _heliSpawn, [], 0, "FLY"];
                _heli setPosATL _heliSpawn;
                _heli setDir (_wavePos getDir _bp);
                _heli engineOn true;
                _heli flyInHeight 150;
                _heli setVelocityModelSpace [0, 40, 0];
                _heli setVariable ["BO_exempt", true, true];
                createVehicleCrew _heli;
                { _x setVariable ["BO_exempt", true, true] } forEach (crew _heli);

                // Passenger paratroopers, capped to heli cargo capacity.
                private _heliCap = getNumber (configFile >> "CfgVehicles" >> _heliClass >> "transportSoldier");
                if (_heliCap < 1) then { _heliCap = _waveSize };
                _heliCap = _heliCap min _waveSize;
                for "_i" from 1 to _heliCap do {
                    private _u = _waveGroup createUnit [selectRandom _pool, _heliSpawn, [], 0, "NONE"];
                    _u setVariable ["BO_exempt", true, true];
                    [_u, "BO_DefectorAttack"] call OT_fnc_initMilitary;
                    _u assignAsCargo _heli;
                    _u moveInCargo _heli;
                };

                // The pilot group is captured INSIDE the spawn block
                // after a wait, not before. createVehicleCrew can be
                // late by 1+ frames in MP -- if we captured `group
                // driver _heli` synchronously and it returned grpNull,
                // the heli would never get its MOVE waypoint and
                // would orbit the spawn point indefinitely. Polling
                // for the driver inside the spawn fixes that race.
                [_heli, _bp, _waveGroup, _jobid] spawn {
                    params ["_heli", "_dropPos", "_squad", "_jobid"];
                    _heli flyInHeight 150;

                    // Wait for the AI pilot to actually exist.
                    private _crewDeadline = diag_tickTime + 10;
                    waitUntil {
                        sleep 0.2;
                        (!alive _heli)
                            || (!isNull driver _heli)
                            || (diag_tickTime > _crewDeadline)
                            || (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] })
                    };
                    if (!alive _heli || isNull driver _heli) exitWith {};
                    if (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] }) exitWith {};

                    private _vehGroup = group driver _heli;
                    if (isNull _vehGroup) exitWith {};

                    // Heli pilot waypoint: fly to drop zone. CARELESS
                    // so they don't peel off engaging targets.
                    private _hWp = _vehGroup addWaypoint [_dropPos, 0];
                    _hWp setWaypointType "MOVE";
                    _hWp setWaypointBehaviour "CARELESS";

                    waitUntil {
                        sleep 1;
                        (!alive _heli)
                            || ((_heli distance2D _dropPos) < 80)
                            || (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] })
                    };
                    if (!alive _heli) exitWith {};
                    if (isNil { missionNamespace getVariable format ["BO_def_waveGroup_%1", _jobid] }) exitWith {};
                    {
                        if (alive _x && (vehicle _x) isEqualTo _heli) then {
                            unassignVehicle _x;
                            _x action ["EJECT", _heli];
                            // 150m AGL needs ~15s under canopy to land.
                            // 20s invuln covers chute deploy + descent
                            // + grace so ragdoll doesn't kill the drop.
                            _x allowDamage false;
                            [_x] spawn { params ["_u"]; sleep 20; if (alive _u) then { _u allowDamage true } };
                            sleep 0.4;
                        };
                    } forEach (units _squad);
                    sleep 3;
                    if (alive _heli && !isNull _vehGroup) then {
                        private _retreat = _vehGroup addWaypoint [_dropPos getPos [3000, random 360], 0];
                        _retreat setWaypointType "MOVE";
                    };
                };

                missionNamespace setVariable [format ["BO_def_waveVeh_%1", _jobid], _heli];
            };

            // Paratroopers' SAD waypoint at the defender. Both the
            // ground and air branch route troops here once they're on
            // foot (force-dismount in the monitor / EJECT in the heli
            // case). SAD makes them search & destroy the player +
            // defender area.
            private _wp = _waveGroup addWaypoint [_bp, 5];
            _wp setWaypointType "SAD";
            _wp setWaypointSpeed "FULL";
            _wp setWaypointBehaviour "AWARE";

            missionNamespace setVariable [format ["BO_def_waveGroup_%1", _jobid], _waveGroup];
        };

        // ---- Phase 2: defence ----
        // Success: defector alive AND (all wave dead OR 15min elapsed).
        if (_triggered) exitWith {
            private _waveGroup = missionNamespace getVariable [format ["BO_def_waveGroup_%1", _jobid], grpNull];
            private _defStart  = missionNamespace getVariable [format ["BO_def_defStart_%1",  _jobid], diag_tickTime];

            if (!alive _defector) exitWith { false };

            private _aliveAttackers = if (isNull _waveGroup) then { 0 } else { { alive _x } count (units _waveGroup) };
            private _elapsed = diag_tickTime - _defStart;

            (_aliveAttackers isEqualTo 0) || (_elapsed >= _defenseDurationSec)
        };

        false
    },
    {
        params ["_jobid", "", "", "", "", "", "_reward", "_wassuccess"];

        private _defector  = missionNamespace getVariable [format ["BO_def_npc_%1",       _jobid], objNull];
        private _civGrp    = missionNamespace getVariable [format ["BO_def_civgrp_%1",    _jobid], grpNull];
        private _waveGroup = missionNamespace getVariable [format ["BO_def_waveGroup_%1", _jobid], grpNull];
        private _waveVeh   = missionNamespace getVariable [format ["BO_def_waveVeh_%1",   _jobid], objNull];

        if (!isNull _waveGroup) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _waveGroup);
        };
        [[_waveGroup, _waveVeh]] call BO_fnc_logMissionDebris;

        if (!isNull _defector && _wassuccess) then {
            _defector enableAI "PATH";
            _defector enableAI "MOVE";
            _defector setUnitPos "AUTO";
            _defector setVariable ["BO_exempt", false, true];
            // Enroll surviving defector + his civ group in the long-despawn registry so towns don't accumulate one idle civ per defector mission.
            [[_civGrp, _defector]] call BO_fnc_logMissionDebris;
        };
        if (!isNull _defector && !_wassuccess) then { deleteVehicle _defector };
        // Only delete the group on FAIL; on success the group is owned by logMissionDebris and will be cleaned with the defector.
        if (!_wassuccess && !isNull _civGrp) then { deleteGroup _civGrp };

        missionNamespace setVariable [format ["BO_def_npc_%1",       _jobid], nil];
        missionNamespace setVariable [format ["BO_def_civgrp_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_def_triggered_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_def_waveGroup_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_def_waveVeh_%1",   _jobid], nil];
        missionNamespace setVariable [format ["BO_def_defStart_%1",  _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Defector Saved"] call OT_fnc_money;
        };
    },
    _params
]
