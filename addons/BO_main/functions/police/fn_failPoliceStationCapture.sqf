#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_failPoliceStationCapture
 *
 * Server-only. Capture attempt failed (caller died, left the circle,
 * or disconnected). Tear down the capture state cleanly:
 *   - Delete the ELLIPSE circle marker
 *   - Despawn the reinforcement convoy
 *   - Clear all BO_polcap_* missionNamespace state for the town
 *
 * Params:
 *   0: STRING - town name
 *   1: STRING - human-readable reason
 */

if (!isServer) exitWith {};

params [["_town", "", [""]], ["_reason", "unknown", [""]]];
if (_town isEqualTo "") exitWith {};

private _activeKey  = format ["BO_polcap_active_%1", _town];
private _circleKey  = format ["BO_polcap_circleId_%1", _town];
private _startKey   = format ["BO_polcap_start_%1", _town];
private _callerKey  = format ["BO_polcap_callerUID_%1", _town];
private _outKey     = format ["BO_polcap_outSince_%1", _town];
private _reinfKey   = format ["BO_polcap_reinforce_%1", _town];
private _pfhKey     = format ["BO_polcap_pfh_%1", _town];

private _circleId = missionNamespace getVariable [_circleKey, ""];
if (_circleId isNotEqualTo "") then { deleteMarker _circleId };

// Despawn the convoy group + vehicle.
private _reinf = missionNamespace getVariable [_reinfKey, []];
if (_reinf isNotEqualTo []) then {
    _reinf params [["_grp", grpNull, [grpNull]], ["_veh", objNull, [objNull]]];
    if (!isNull _grp) then {
        { deleteVehicle _x } forEach (units _grp);
        deleteGroup _grp;
    };
    if (!isNull _veh) then { deleteVehicle _veh };
};

// Clear state.
missionNamespace setVariable [_activeKey,  nil, true];
missionNamespace setVariable [_circleKey,  nil, true];
missionNamespace setVariable [_startKey,   nil, true];
missionNamespace setVariable [_callerKey,  nil, true];
missionNamespace setVariable [_outKey,     nil, true];
missionNamespace setVariable [_reinfKey,   nil, true];
missionNamespace setVariable [_pfhKey,     nil, true];

private _msg = format ["Capture of %1 police station failed: %2", _town, _reason];
_msg remoteExec ["OT_fnc_notifyBad", 0, false];
[AUDIT_ADMIN, _msg, [_town, _reason], "", ""] call BO_fnc_auditServer;
BO_LOG_INFO("police", _msg);
