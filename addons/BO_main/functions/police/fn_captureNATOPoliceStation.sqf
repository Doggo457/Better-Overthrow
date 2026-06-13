#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_captureNATOPoliceStation
 *
 * Server-only. Flips a registered station to captured state:
 * marker + flag perm-deleted, building/crates/vehicle ownership
 * transferred to the player whose hold completed the capture
 * (BO_polcap_callerUID_<town>, set in fn_startPoliceStationCapture),
 * +5 town stability, broadcast notify crediting the captor by name.
 *
 * Params:
 *   0: STRING - town name
 */

if (!isServer) exitWith {};

params [["_town", "", [""]]];
if (_town isEqualTo "") exitWith {};

private _stations = server getVariable ["BO_natoPoliceStations", []];
private _idx = _stations findIf { (_x select 0) isEqualTo _town };
if (_idx < 0) exitWith {};

private _entry = _stations select _idx;
if (_entry select 2) exitWith {}; // already captured

private _buildingNetId = _entry select 3;
private _crateNetIds   = _entry select 4;
private _vehicleNetId  = _entry select 5;
private _markerId      = _entry select 7;
private _flagNetId     = _entry param [9, ""];

// Ownership of the spoils goes to the player who completed the
// capture. Fall back to the first General only if no caller UID
// was recorded (defensive -- the start path always sets it).
private _captorUID = missionNamespace getVariable [format ["BO_polcap_callerUID_%1", _town], ""];
if (_captorUID isEqualTo "") then {
    private _generals = server getVariable ["generals", []];
    if (count _generals > 0) then { _captorUID = _generals select 0 };
};

if (_captorUID isNotEqualTo "") then {
    private _building = objectFromNetId _buildingNetId;
    if (!isNull _building) then {
        [_building, _captorUID] call OT_fnc_setOwner;
    };
    {
        private _c = objectFromNetId _x;
        if (!isNull _c) then {
            [_c, _captorUID] call OT_fnc_setOwner;
        };
    } forEach _crateNetIds;
    private _veh = objectFromNetId _vehicleNetId;
    if (!isNull _veh && {alive _veh}) then {
        [_veh, _captorUID] call OT_fnc_setOwner;
    };
};

// Permanently delete the marker -- the police station is "gone"
// until NATO retakes the town. fn_recaptureNATOPoliceStation (hooked
// from fn_NATOCounterTown success) reruns the full spawn pipeline
// which creates a fresh marker.
if (_markerId isNotEqualTo "") then {
    deleteMarker _markerId;
    // Clear the marker id in the registry so cleanup paths don't try
    // to delete it again.
    _entry set [7, ""];
};

// Delete the NATO flag -- the station is no longer NATO's; the
// addAction goes with it.
if (_flagNetId isNotEqualTo "") then {
    private _flag = objectFromNetId _flagNetId;
    if (!isNull _flag) then { deleteVehicle _flag };
};

// Tear down the capture circle + reinforcements + state.
private _circleId = missionNamespace getVariable [format ["BO_polcap_circleId_%1", _town], ""];
if (_circleId isNotEqualTo "") then { deleteMarker _circleId };
private _reinf = missionNamespace getVariable [format ["BO_polcap_reinforce_%1", _town], []];
if (_reinf isNotEqualTo []) then {
    _reinf params [["_grp", grpNull, [grpNull]], ["_veh", objNull, [objNull]]];
    // Reinforcements arrived too late -- but rather than auto-kill,
    // leave them in the field as ambient enemies. Just drop the
    // tracking entry so the convoy isn't double-cleaned later.
};
{
    missionNamespace setVariable [format [_x, _town], nil, true];
} forEach [
    "BO_polcap_active_%1", "BO_polcap_circleId_%1", "BO_polcap_start_%1",
    "BO_polcap_callerUID_%1", "BO_polcap_outSince_%1",
    "BO_polcap_reinforce_%1", "BO_polcap_pfh_%1"
];

_entry set [2, true];
_stations set [_idx, _entry];
server setVariable ["BO_natoPoliceStations", _stations, true];

// Resolve captor display name so the global notify + audit credit
// the player who took the station instead of attributing to "the
// resistance" abstractly.
private _captorName = "the resistance";
if (_captorUID isNotEqualTo "") then {
    private _captorIdx = allPlayers findIf { getPlayerUID _x isEqualTo _captorUID };
    if (_captorIdx >= 0) then { _captorName = name (allPlayers select _captorIdx) };
};
private _msg = format ["%1 captured the NATO police station at %2", _captorName, _town];
_msg remoteExec ["OT_fnc_notifyMinor", 0, false];
BO_LOG_INFO("police", _msg);

[AUDIT_ADMIN, format ["NATO Police Station captured at %1 by %2", _town, _captorName], [_town, _captorUID], _captorUID, _captorName] call BO_fnc_auditServer;

// Stability bonus -- the resistance's hard-fought win is visible.
[_town, 5] call OT_fnc_stability;
