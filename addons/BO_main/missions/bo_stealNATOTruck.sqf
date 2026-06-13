/*
 * BO mission: Steal NATO Truck
 *
 * Target = Town. Picks a NATO-controlled town; spawns a NATO
 * transport truck (OT_NATO_Vehicle_Transport) on the outskirts
 * with a flat front-left wheel and a spare tyre + ToolKit on the
 * ground next to it. Two NATO guards are watching it.
 *
 * Narrative: NATO truck broke down on the perimeter; the crew
 * abandoned it and a couple of riflemen are guarding it until the
 * repair team arrives. Player kills the guards, gets in the truck
 * (any seat), and the truck is theirs to repair and drive.
 *
 * Success: any player in the truck's crew. The flat tyre is just
 * gameplay flavor -- the truck doesn't have to move to complete
 * the mission. On success the truck transfers to player ownership
 * via OT_fnc_setOwner so it persists and shows in their owned-
 * vehicle list.
 *
 * All map-portable -- OT_NATO_Vehicle_Transport varies per map
 * (T-camo on Livonia/Tanoa, woodland on Altis/Malden).
 */

params ["_jobid", "_jobparams"];

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

private _spotPos = [];
for "_attempt" from 1 to 15 do {
    private _candidate = [_townPos, 150, 350, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_candidate isEqualType [] && {(count _candidate) >= 2} && {(_candidate select 0) > 0}) exitWith {
        // findSafePos returns 2D; setPosATL needs 3D.
        _spotPos = [_candidate select 0, _candidate select 1, 0];
    };
};
if (_spotPos isEqualTo []) exitWith { [] };

private _truckPool = OT_NATO_Vehicle_Transport;
if (isNil "_truckPool" || { _truckPool isEqualTo [] }) then { _truckPool = [OT_NATO_Vehicle_Transport_Light] };
private _truckClass = selectRandom _truckPool;

private _reward = 4000;

private _title = format ["Steal NATO Truck at %1", _townName];
private _description = format [
    "A NATO transport (%1) is parked at the edge of %2 with a flat tyre and two guards. Take out the guards, get in the truck -- it's yours. A spare tyre and toolkit are on the ground next to it if you want to drive it home.<br/><br/>Reward: $%3 + the truck",
    getText (configFile >> "CfgVehicles" >> _truckClass >> "displayName"),
    _townName, _reward
];

private _params = [_jobid, _spotPos, _truckClass, _reward];

[
    [_title, _description],
    _spotPos,
    {
        params ["_jobid", "_spotPos", "_truckClass"];

        // Truck spawns with a flat front-left wheel. Engine/fuel
        // intact -- player just needs to swap the wheel to drive it.
        private _truck = _truckClass createVehicle _spotPos;
        _truck setPosATL _spotPos;
        _truck setDir (random 360);
        _truck setVariable ["BO_exempt", true, true];
        _truck setHitPointDamage ["HitLFWheel", 1, true];

        // Spare wheel on the ground next to the truck. ACE_Wheel is
        // a CfgVehicles class -- a physical object you createVehicle,
        // NOT an addItemCargo-able inventory item. The player uses
        // ACE Interact > "Load" to load it into the truck's ACE
        // cargo, then ACE Interact > "Replace Wheel" on the damaged
        // wheel hitpoint to install it.
        //
        // Computing the ground spot: modelToWorld gives us the XY
        // offset from the truck's local frame; for Z we want
        // terrain level (NOT axle height like a raw modelToWorld
        // would give us), so we force the Z to 0 in the setPosATL
        // call below. We also reuse fn_buy's `ace_repair_fnc_addSpareParts`
        // pattern as a backup -- in case the ground wheel gets
        // destroyed by an errant grenade, the truck itself has a
        // spare inside its ACE cargo.
        private _spotXY = _truck modelToWorld [-3, 1, 0];
        private _wheelGroundPos = [_spotXY select 0, _spotXY select 1, 0];

        private _wheel = "ACE_Wheel" createVehicle _wheelGroundPos;
        _wheel setPosATL _wheelGroundPos;

        // Backup: one spare in the truck's ACE cargo + a ToolKit in
        // the vehicle inventory for the vanilla repair fallback.
        if (!isNil "ace_repair_fnc_addSpareParts") then {
            [_truck, 1, "ACE_Wheel"] call ace_repair_fnc_addSpareParts;
        };
        _truck addItemCargoGlobal ["ToolKit", 1];

        // Two guards near the truck (not in it).
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };
        for "_i" from 1 to 2 do {
            // Tempest is ~9.7m long; 4-8m on a full ring puts guards inside the truck's bounding box along its long axis -> physics ejection. 7-10m clears the longest transport in the pool.
            private _spawnPos = _spotPos getPos [7 + random 3, random 360];
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, 0];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_StealTruck"] call OT_fnc_initMilitary;
        };
        [_group, _spotPos, 12, 3] call CBA_fnc_taskPatrol;

        missionNamespace setVariable [format ["BO_steal_truck_%1", _jobid], _truck];
        missionNamespace setVariable [format ["BO_steal_group_%1", _jobid], _group];
        missionNamespace setVariable [format ["BO_steal_wheel_%1", _jobid], _wheel];
        true
    },
    {
        // Fail only if truck is destroyed.
        params ["_jobid"];
        private _truck = missionNamespace getVariable [format ["BO_steal_truck_%1", _jobid], objNull];
        isNull _truck || { !alive _truck }
    },
    {
        params ["_jobid"];
        private _truck = missionNamespace getVariable [format ["BO_steal_truck_%1", _jobid], objNull];
        if (isNull _truck || { !alive _truck }) exitWith { false };

        // Success the moment any player is in the truck's crew (any
        // seat). The truck doesn't have to move -- the flat tyre
        // makes it impossible to drive without a repair, and that's
        // intentional. The truck is loot.
        ((crew _truck) findIf { isPlayer _x }) >= 0
    },
    {
        params ["_jobid", "", "", "_reward", "_wassuccess"];

        private _truck = missionNamespace getVariable [format ["BO_steal_truck_%1", _jobid], objNull];
        private _group = missionNamespace getVariable [format ["BO_steal_group_%1", _jobid], grpNull];
        private _wheel = missionNamespace getVariable [format ["BO_steal_wheel_%1", _jobid], objNull];

        // Bodies stay for looting; OT GC handles their decay timer.
        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };

        if (_wassuccess && !isNull _truck) then {
            // Hand the truck to whichever player got in.
            private _newOwner = effectiveCommander _truck;
            if (isNull _newOwner || !isPlayer _newOwner) then {
                _newOwner = driver _truck;
            };
            if (isNull _newOwner || !isPlayer _newOwner) then {
                // Fallback -- anyone in the crew.
                _newOwner = (crew _truck) param [0, objNull];
            };
            if (!isNull _newOwner && isPlayer _newOwner) then {
                [_truck, getPlayerUID _newOwner] call OT_fnc_setOwner;
            };
            // Truck is now player-owned and permanent. Keep BO_exempt
            // = true so the BO garbage collector never touches it,
            // and don't enrol it in the mission-debris despawn
            // registry. OT save persists it across reload via the
            // owner UID set above.
            _truck setVariable ["BO_exempt", true, true];
        };

        // Ground wheel + bodies stay via the long-despawn registry.
        // On SUCCESS the wheel is likely already inside the truck or
        // installed on it -- pass it in either way; logMissionDebris
        // is defensive against deleted/null objects.
        // Truck is in the registry ONLY on fail (when it's a wreck,
        // not the player's). On success the truck is permanent and
        // explicitly excluded.
        private _debris = [_group, _wheel];
        if (!_wassuccess && !isNull _truck) then { _debris pushBack _truck };
        [_debris] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_steal_truck_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_steal_group_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_steal_wheel_%1", _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Stole NATO Truck"] call OT_fnc_money;
        };
    },
    _params
]
