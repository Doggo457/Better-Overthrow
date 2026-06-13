#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_callCAS
 *
 * Server-auth CAS dispatch. Re-checks cooldown + bank, debits, stamps
 * BO_lastCASMission, spawns an AI helicopter (independent side, so it
 * matches the resistance) 1.5km from the target at 200m, gives it a
 * SAD waypoint on the target and a MOVE waypoint home that cleans
 * itself up. A 10-minute hard-cleanup CBA_fnc_waitAndExecute fires
 * regardless of waypoint state to keep stragglers off the map.
 *
 * The parked heli is NOT consumed -- it sits as a "we have CAS
 * available" marker. The dispatched heli is a separate AI entity.
 *
 * Server-only. Audits at AUDIT_ARTILLERY.
 *
 * Params:
 *   0: OBJECT - helipad
 *   1: STRING - heli class
 *   2: ARRAY  - target position
 *   3: SCALAR - cost (preview value sent from client; we re-derive
 *               authoritative cost from BO_casLoadouts below)
 *   4: STRING - caller UID
 */

SERVER_ONLY;

params [
    ["_pad", objNull, [objNull]],
    ["_vehClass", "", [""]],
    ["_pos", [0,0,0], [[]]],
    ["_cost", 0, [0]],
    ["_callerUID", "", [""]]
];
if (isNull _pad) exitWith {};

if (isNil "BO_casLoadouts" || {!(_vehClass in (keys BO_casLoadouts))}) exitWith {
    BO_LOG_WARN("artillery", "callCAS rejected: unsupported heli class");
};

// Authoritative cost = server-side lookup, not client value.
_cost = BO_casLoadouts getOrDefault [_vehClass, 8000];

// Resolve caller for notification routing.
private _callerIdx = allPlayers findIf { getPlayerUID _x isEqualTo _callerUID };
private _callerObj = if (_callerIdx >= 0) then { allPlayers select _callerIdx } else { objNull };
private _callerOwner = if (!isNull _callerObj) then { owner _callerObj } else { 0 };

// Generals-only -- defensive server-side check.
private _generals = server getVariable ["generals", []];
if !(_callerUID in _generals) exitWith {
    if (_callerOwner > 0) then {
        "Only Generals can request CAS" remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
    private _rmsg = format ["callCAS rejected: non-General caller uid=%1", _callerUID];
    BO_LOG_WARN("artillery", _rmsg);
};

private _casCd = missionNamespace getVariable ["BO_casCooldownSec", 1200];
private _last = _pad getVariable ["BO_lastCASMission", 0];
if ((serverTime - _last) < _casCd) exitWith {
    private _msg = format ["CAS on cooldown (%1s)", round (_last + _casCd - serverTime)];
    if (_callerOwner > 0) then {
        _msg remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
};

private _bal = 0;
if (!isNull _callerObj) then {
    _bal = _callerObj getVariable ["BO_bank", 0];
} else {
    _bal = [_callerUID, "BO_bank", 0] call OT_fnc_getOfflinePlayerAttribute;
};
if (_bal < _cost) exitWith {
    private _msg = format ["Insufficient bank funds (need $%1, have $%2)", _cost, _bal];
    if (_callerOwner > 0) then {
        _msg remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
};

private _debitDesc = format ["CAS dispatch %1", _vehClass];
[_callerUID, -_cost, _debitDesc] call BO_fnc_bankAdjust;

_pad setVariable ["BO_lastCASMission", serverTime, true];

// Spawn 1.5km away from target at 200m, random bearing, so the heli
// has a clean approach run.
private _spawnDir = random 360;
private _spawnPos = [_pos, 1500, _spawnDir] call BIS_fnc_relPos;
_spawnPos set [2, 200];

private _grp = createGroup [independent, true];
private _heli = createVehicle [_vehClass, _spawnPos, [], 0, "FLY"];
_heli setPosATL _spawnPos;
_heli flyInHeight 150;
private _autoGrp = createVehicleCrew _heli;
{ [_x] joinSilent _grp } forEach (crew _heli);
// The auto-created crew group is now empty; mark it for cleanup so
// it doesn't linger for the mission lifetime each CAS call.
if (!isNull _autoGrp) then { _autoGrp deleteGroupWhenEmpty true };
_grp deleteGroupWhenEmpty true;
_grp setGroupIdGlobal ["CAS"];

_heli setVariable ["BO_playerCASMission", _callerUID, true];
_heli setVariable ["BO_fireMissionType", "CAS", true];
_heli addEventHandler ["Killed", {
    (_this select 0) setVariable ["OT_garbage_eligible", true, true];
}];

private _wp = _grp addWaypoint [_pos, 0];
_wp setWaypointType "SAD";
_wp setWaypointSpeed "FULL";
_wp setWaypointBehaviour "COMBAT";

private _wp2 = _grp addWaypoint [_spawnPos, 0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointStatements ["true", "{ deleteVehicle _x } forEach crew (vehicle this); deleteVehicle (vehicle this);"];

private _auditMsg = format ["CAS dispatched: %1 -> %2 by %3 ($%4)",
    _vehClass, mapGridPosition _pos, _callerUID, _cost];
[AUDIT_ARTILLERY,
    _auditMsg,
    [getPosATL _pad, _pos, _vehClass, _callerUID, _cost],
    "",
    ""
] call BO_fnc_auditServer;

private _inboundMsg = format ["CAS inbound to grid %1", mapGridPosition _pos];
_inboundMsg remoteExec ["OT_fnc_notifyBig", 0, false];

// Safety net: hard cleanup at 10 min regardless of waypoint state.
[{
    params ["_heli"];
    if (isNull _heli) exitWith {};
    { deleteVehicle _x } forEach (crew _heli);
    deleteVehicle _heli;
}, [_heli], 600] call CBA_fnc_waitAndExecute;
