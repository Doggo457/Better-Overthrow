#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_postLoadHydratePolice
 *
 * Reconstitutes BO_natoPoliceStations after a save/load round-trip.
 * The registry itself auto-persists via OT's slot-1 server-var scan.
 * What does NOT persist and must be rebound here:
 *
 *   - netIds (slots 3, 5, 9): live objects get fresh netIds on load.
 *   - markers (slot 7): session-local. Captured rows correctly hold ""
 *     and must NOT regain a marker. Uncaptured rows need
 *     BO_polstation_<town> repainted.
 *   - flag (slot 9): createVehicle output, not flagged for OT save.
 *     Captured: stay deleted. Uncaptured: respawn at building.
 *   - spawner registration (slot 10): code ref is fragile across save;
 *     captured rows leave dead OT_allSpawners entries behind.
 *     Deregister-then-rebind for uncaptured; deregister-only for
 *     captured.
 *   - runtime owner setVariable stamp: persistent 'owners' namespace
 *     survives, but per-object setVariable ["owner"] dies. Re-apply.
 *
 * Idempotent; safe to call on every load.
 */

if (!isServer) exitWith {};

private _stations = server getVariable ["BO_natoPoliceStations", []];
if (_stations isEqualTo []) exitWith {
    BO_LOG_INFO("police", "postLoadHydratePolice: no stations to hydrate");
};

private _t0 = diag_tickTime;
private _hydratedActive   = 0;
private _hydratedCaptured = 0;
private _dropped          = 0;

private _newStations = [];
{
    private _entry = _x;
    _entry params [
        ["_town",         "",      [""]],
        ["_stationPos",   [0,0,0], [[]]],
        ["_captured",     false,   [false]],
        ["_buildingNetId","",      [""]],
        ["_crateNetIds",  [],      [[]]],
        ["_vehicleNetId", "",      [""]],
        ["_garrisonGrp",  grpNull, [grpNull]],
        ["_markerId",     "",      [""]],
        ["_adopted",      false,   [false]],
        ["_flagNetId",    "",      [""]],
        ["_spawnerId",    "",      [""]],
        ["_bps",          [],      [[]]]
    ];

    private _building = objNull;
    if (_adopted) then {
        private _candidates = nearestObjects [_stationPos, ["House"], 8];
        {
            if (((getPosATL _x) distance _stationPos) < 3 && {alive _x}) exitWith {
                _building = _x;
            };
        } forEach _candidates;
    } else {
        private _candidates = nearestObjects [_stationPos, [OT_policeStation], 12];
        if (count _candidates > 0) then { _building = _candidates select 0 };
    };

    if (isNull _building) then {
        private _wmsg = format ["postLoadHydratePolice: %1 building gone, dropping entry", _town];
        BO_LOG_WARN("police", _wmsg);
        _dropped = _dropped + 1;
    } else {
        _building setVariable ["BO_natoStationOwner", _town, true];

        if (_captured) then {
            // OT_fnc_setOwner keys ownership on getBuildID, not str _building.
            private _captorUID = owners getVariable [[_building] call OT_fnc_getBuildID, ""];
            if (_captorUID isNotEqualTo "" && {_captorUID isNotEqualTo "NATO_POLICE"}) then {
                _building setVariable ["owner", _captorUID, true];
            };
        } else {
            [_building, "NATO_POLICE"] call OT_fnc_setOwner;
        };

        _entry set [3, netId _building];
        _entry set [4, []];
        _entry set [5, ""];
        _entry set [6, grpNull];

        if (_spawnerId isNotEqualTo "") then {
            // deregisterSpawner compares _x#0 isEqualTo _this against the
            // bare "spawnN" string stored in OT_allSpawners -- an array
            // wrap [_spawnerId] never matches and leaks the entry.
            _spawnerId call OT_fnc_deregisterSpawner;
        };

        if (_captured) then {
            _entry set [7, ""];
            _entry set [9, ""];
            _entry set [10, ""];
            _hydratedCaptured = _hydratedCaptured + 1;
        } else {
            private _mkid = format ["BO_polstation_%1", _town];
            deleteMarker _mkid;
            createMarker [_mkid, _stationPos];
            _mkid setMarkerType "o_installation";
            _mkid setMarkerColor "ColorBLUFOR";
            _mkid setMarkerText (format ["Police: %1", _town]);
            _mkid setMarkerSize [0.5, 0.5];
            _mkid setMarkerAlpha 1;
            _entry set [7, _mkid];

            private _flagPos = _building getPos [3 + random 2, random 360];
            private _flag = createVehicle [OT_flag_NATO, _flagPos, [], 0, "NONE"];
            _flag setPosATL _flagPos;
            _flag setVariable ["BO_natoStationOwner", _town, true];
            _flag setVariable ["BO_natoStationFlag", _town, true];
            _entry set [9, netId _flag];

            private _spawnerNum = [_stationPos, BO_fnc_spawnPoliceStationGarrison, [_town, _bps]] call OT_fnc_registerSpawner;
            _entry set [10, format ["spawn%1", _spawnerNum]];

            _hydratedActive = _hydratedActive + 1;
        };

        _newStations pushBack _entry;
    };
} forEach _stations;

server setVariable ["BO_natoPoliceStations", _newStations, true];

// Stale capture-mini-game state from the prior session is invalid on load.
// PFH handles + circle markers + per-town timers all die; null them out so
// a fresh Y-menu capture works cleanly.
{
    private _town = _x select 0;
    {
        missionNamespace setVariable [format [_x, _town], nil, true];
    } forEach [
        "BO_polcap_active_%1", "BO_polcap_circleId_%1", "BO_polcap_start_%1",
        "BO_polcap_callerUID_%1", "BO_polcap_outSince_%1",
        "BO_polcap_reinforce_%1", "BO_polcap_pfh_%1"
    ];
    deleteMarker (format ["BO_polcap_circle_%1", _x select 0]);
} forEach _newStations;

private _elapsed = diag_tickTime - _t0;
private _msg = format ["postLoadHydratePolice: %1 active + %2 captured rebound, %3 dropped, %4s",
    _hydratedActive, _hydratedCaptured, _dropped, _elapsed];
BO_LOG_INFO("police", _msg);
[AUDIT_SAVE, _msg, [_hydratedActive, _hydratedCaptured, _dropped, _elapsed], "", ""] call BO_fnc_auditServer;
