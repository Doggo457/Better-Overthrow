#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_spawnNATOPoliceStation
 *
 * Server-only. Persistent setup pass for a police station:
 *   - Adopts a random town building (sentinel owner blocks missions)
 *   - Drops a NATO flag at the building (always alive)
 *   - Installs a "Capture Police Station: <town>" addAction on the flag
 *   - Creates a half-size map marker (always visible)
 *   - Registers an OT spawner so the SWAT garrison + crates + vehicle
 *     spawn-on-approach and despawn-on-leave (virtualization).
 *
 * Does NOT spawn units/crates/vehicle here -- that's deferred to
 * BO_fnc_spawnPoliceStationGarrison, which OT's spawn loop fires
 * when a player enters spawn distance.
 *
 * Params:
 *   0: STRING - town name
 *
 * Returns: BOOL - true on register, false on skip/failure.
 */

if (!isServer) exitWith { false };

params [["_town", "", [""]]];
if (_town isEqualTo "") exitWith { false };

private _stations = server getVariable ["BO_natoPoliceStations", []];
private _existingIdx = _stations findIf { (_x select 0) isEqualTo _town };
if (_existingIdx >= 0) exitWith {
    private _msg = format ["spawnNATOPoliceStation: %1 already registered", _town];
    BO_LOG_DEBUG("police", _msg);
    false
};

private _townPos = server getVariable _town;
if (isNil "_townPos") exitWith {
    private _msg = format ["spawnNATOPoliceStation: no position for town %1", _town];
    BO_LOG_WARN("police", _msg);
    false
};

// -- Pick a random existing town building (>=4 buildingPos) --
private _building = objNull;
private _bps = [];
private _townHouses = (nearestObjects [_townPos, ["House"], 250]) select {
    !(_x call OT_fnc_hasOwner) && {alive _x}
};
{
    private _h = _x;
    private _slots = (_h buildingPos -1) select {!(_x isEqualTo [0,0,0])};
    if (count _slots >= 4) then {
        _building = _h;
        _bps = _slots;
    };
    if (!isNull _building) exitWith {};
} forEach (_townHouses call BIS_fnc_arrayShuffle);

private _stationPos = [0,0,0];
private _adopted = !isNull _building;

if (_adopted) then {
    _stationPos = getPosATL _building;
} else {
    // Fallback: createVehicle the OT police station class.
    private _attempts = 0;
    while { _attempts < 6 && _stationPos isEqualTo [0,0,0] } do {
        private _try = _townPos getPos [80 + (random 100), random 360];
        private _empty = _try findEmptyPosition [10, 60, OT_policeStation];
        if (_empty isNotEqualTo []) then { _stationPos = _empty };
        _attempts = _attempts + 1;
    };
    if (_stationPos isEqualTo [0,0,0]) then {
        _stationPos = _townPos getPos [120, random 360];
    };
    _building = createVehicle [OT_policeStation, _stationPos, [], 0, "NONE"];
    _building setPosATL _stationPos;
    _building setDir (random 360);
    _building setVariable ["OT_forceSaveUnowned", true, true];
    _bps = (_building buildingPos -1) select {!(_x isEqualTo [0,0,0])};
};

// -- Sentinel owner blocks OT_fnc_getRandomBuilding + BO mission scans --
[_building, "NATO_POLICE"] call OT_fnc_setOwner;
_building setVariable ["BO_natoStationOwner", _town, true];

// -- NATO flagpole in front of the building. Visual marker of NATO
// ownership; the capture trigger lives on the Y menu (fn_mainMenu)
// not on the flag itself. The flag is deleted on capture and re-
// created on NATO recapture. --
private _flagPos = _building getPos [3 + random 2, random 360];
private _flag = createVehicle [OT_flag_NATO, _flagPos, [], 0, "NONE"];
_flag setPosATL _flagPos;
_flag setVariable ["BO_natoStationOwner", _town, true];
_flag setVariable ["BO_natoStationFlag", _town, true];

// -- Half-size map marker -- always visible regardless of spawn state --
private _mkid = format ["BO_polstation_%1", _town];
deleteMarker _mkid;
createMarker [_mkid, _stationPos];
_mkid setMarkerType "o_installation";
_mkid setMarkerColor "ColorBLUFOR";
_mkid setMarkerText (format ["Police: %1", _town]);
_mkid setMarkerSize [0.5, 0.5];
_mkid setMarkerAlpha 1;

// -- Register OT spawner. Garrison + crates + vehicle spawn when a
// player enters OT_spawnDistance and despawn when they leave. --
private _spawnerNum = [_stationPos, BO_fnc_spawnPoliceStationGarrison, [_town, _bps]] call OT_fnc_registerSpawner;
private _spawnerId  = format ["spawn%1", _spawnerNum];

// -- Register --
private _entry = [
    _town,                  // 0
    _stationPos,            // 1
    false,                  // 2 captured
    netId _building,        // 3
    [],                     // 4 crates (filled by spawner callback when player approaches; cleared on despawn)
    "",                     // 5 vehicle netId (same; transient)
    grpNull,                // 6 garrison group (transient)
    _mkid,                  // 7 marker id
    _adopted,               // 8
    netId _flag,            // 9 flag
    _spawnerId,             // 10 OT spawner registration id
    _bps                    // 11 cached buildingPos list (used by spawner callback)
];
_stations pushBack _entry;
server setVariable ["BO_natoPoliceStations", _stations, true];

private _msg = format ["Police Station registered at %1 (adopted=%2, spawnerId=%3)", _town, _adopted, _spawnerId];
BO_LOG_INFO("police", _msg);
[AUDIT_ADMIN, format ["Police Station registered at %1", _town], [_town, _stationPos, _adopted], "", ""] call BO_fnc_auditServer;

true
