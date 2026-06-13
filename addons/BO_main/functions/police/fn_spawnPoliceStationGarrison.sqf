#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_spawnPoliceStationGarrison
 *
 * OT spawner callback. Fired by the OT virtualization layer when a
 * player enters spawn distance of a registered police station.
 * Creates SWAT garrison + 2 loot crates + 1 police vehicle. Skips
 * entirely if the station is already captured (resistance owns it,
 * no NATO defenders should appear).
 *
 * Pushes every spawned object/group into spawner getVariable [_id],
 * so OT's despawn pass (fn_despawn) cleans them all up when the
 * player leaves spawn distance.
 *
 * Params (passed via OT_fnc_registerSpawner's _params + spawnerId):
 *   0: STRING - town name
 *   1: ARRAY  - cached buildingPos list (filtered, non-zero only)
 *   2: STRING - spawnerId (OT auto-appends this when firing)
 */

if (!isServer) exitWith {};

params [
    ["_town", "", [""]],
    ["_bps", [], [[]]],
    ["_spawnerId", "", [""]]
];
if (_town isEqualTo "" || {_spawnerId isEqualTo ""}) exitWith {};

private _stations = server getVariable ["BO_natoPoliceStations", []];
private _idx = _stations findIf { (_x select 0) isEqualTo _town };
if (_idx < 0) exitWith {};

private _entry = _stations select _idx;
if (_entry select 2) exitWith {
    private _msg = format ["spawnPoliceStationGarrison: %1 already captured, skip", _town];
    BO_LOG_DEBUG("police", _msg);
};

private _building = objectFromNetId (_entry select 3);
if (isNull _building) exitWith {
    private _msg = format ["spawnPoliceStationGarrison: %1 building null", _town];
    BO_LOG_WARN("police", _msg);
};

private _groups = spawner getVariable [_spawnerId, []];

// -- Crates -- small BLUFOR weapons crates, two per station. Stocked
// with SWAT loadout. Pushed to _groups so OT despawn deletes them.
private _bpsPool = +_bps;
private _crates = [];
private _crateCls = "Box_NATO_Wps_F";
for "_i" from 0 to 1 do {
    private _cratePos = [];
    if (count _bpsPool > 0) then {
        _cratePos = _bpsPool deleteAt (floor (random count _bpsPool));
    } else {
        _cratePos = _building getPos [4 + (random 3), (90 * _i) + (random 60)];
    };
    private _crate = createVehicle [_crateCls, _cratePos, [], 0, "NONE"];
    _crate setPosATL _cratePos;
    clearWeaponCargoGlobal   _crate;
    clearMagazineCargoGlobal _crate;
    clearBackpackCargoGlobal _crate;
    clearItemCargoGlobal     _crate;

    if (!isNil "OT_NATO_weapons_Pistols") then {
        { _crate addWeaponCargoGlobal [_x, 2] } forEach OT_NATO_weapons_Pistols;
    };
    private _rifle = if (!isNil "OT_allBLURifles" && {OT_allBLURifles isNotEqualTo []})
        then { selectRandom OT_allBLURifles } else { "arifle_SPAR_01_blk_F" };
    _crate addWeaponCargoGlobal [_rifle, 4];
    _crate addMagazineCargoGlobal ["30Rnd_556x45_Stanag", 30];
    _crate addMagazineCargoGlobal ["16Rnd_9x21_Mag", 20];
    _crate addMagazineCargoGlobal ["SmokeShell", 10];
    _crate addMagazineCargoGlobal ["HandGrenade", 6];
    _crate addItemCargoGlobal ["FirstAidKit", 10];
    if (!isNil "OT_vest_police") then { _crate addItemCargoGlobal [OT_vest_police, 6] };
    if (!isNil "OT_hat_police")  then { _crate addItemCargoGlobal [OT_hat_police, 6] };

    _crate setVariable ["BO_natoStationOwner", _town, true];
    _crates pushBack _crate;
    _groups pushBack _crate;
};

// -- Police vehicle parked on the nearest road --
// Previously we picked a random offset behind the building, which
// often dropped the car into a wall / fence / other vehicle and the
// physics resolver detonated it. Now we anchor to BIS_fnc_nearestRoad
// and use findEmptyPosition with the vehicle's own bbox for clearance.
private _vehCls = if (!isNil "OT_NATO_Vehicle_Police") then { OT_NATO_Vehicle_Police } else { OT_NATO_Vehicle_Transport_Light };
private _road = [getPosATL _building] call BIS_fnc_nearestRoad;
private _vehPos = [];
if (!isNull _road && {(_road distance _building) < 120}) then {
    _vehPos = (getPos _road) findEmptyPosition [4, 30, _vehCls];
    if (_vehPos isEqualTo []) then { _vehPos = getPos _road };
} else {
    _vehPos = (_building getPos [15, random 360]) findEmptyPosition [8, 40, _vehCls];
    if (_vehPos isEqualTo []) then { _vehPos = _building getPos [20, random 360] };
};
private _vehicle = createVehicle [_vehCls, _vehPos, [], 0, "NONE"];
_vehicle setPosATL _vehPos;
// Orient with the road if we placed it there; else random.
if (!isNull _road) then {
    private _roadsTo = roadsConnectedTo _road;
    if (count _roadsTo > 0) then {
        _vehicle setDir (_road getDir (_roadsTo select 0));
    } else {
        _vehicle setDir (random 360);
    };
} else {
    _vehicle setDir (random 360);
};
_vehicle setVariable ["BO_natoStationOwner", _town, true];
_groups pushBack _vehicle;

// -- SWAT garrison --
private _grp = createGroup [blufor, true];
// Faction-aware fallback to the per-map TeamLeader so non-vanilla
// factions without Gendarmerie classes still spawn on-faction.
private _commanderCls = if (!isNil "OT_NATO_Unit_PoliceCommander_Heavy") then { OT_NATO_Unit_PoliceCommander_Heavy } else { OT_NATO_Unit_TeamLeader };
private _soldierCls   = if (!isNil "OT_NATO_Unit_Police_Heavy")          then { OT_NATO_Unit_Police_Heavy }          else { OT_NATO_Unit_TeamLeader };
private _medicCls     = if (!isNil "OT_NATO_Unit_PoliceMedic_Heavy")     then { OT_NATO_Unit_PoliceMedic_Heavy }     else { OT_NATO_Unit_TeamLeader };

private _spawnLoadout = [_commanderCls, _soldierCls, _soldierCls, _soldierCls, _medicCls];
private _gPool = +_bpsPool;
{
    private _slot = [0,0,0];
    if (count _gPool > 0) then {
        _slot = _gPool deleteAt (floor (random count _gPool));
    } else {
        _slot = _building getPos [5 + (random 3), _forEachIndex * 72];
    };
    private _u = _grp createUnit [_x, _slot, [], 0, "NONE"];
    _u setPosATL [_slot select 0, _slot select 1, (_slot select 2) + 0.2];
    _u setVariable ["BO_natoStationOwner", _town, true];
    _u setBehaviour "SAFE";
} forEach _spawnLoadout;
_grp setBehaviour "SAFE";
[_grp, _building, 25] call CBA_fnc_taskDefend;
_groups pushBack _grp;

// Cache the live refs back on the registry entry so capture / fail
// paths can find them this session.
_entry set [4, _crates apply { netId _x }];
_entry set [5, netId _vehicle];
_entry set [6, _grp];
_stations set [_idx, _entry];
server setVariable ["BO_natoPoliceStations", _stations, true];

// Hand the OT despawn loop the master object/group list.
spawner setVariable [_spawnerId, _groups, false];

private _msg = format ["Police garrison spawned at %1 (group=%2)", _town, _grp];
BO_LOG_DEBUG("police", _msg);
