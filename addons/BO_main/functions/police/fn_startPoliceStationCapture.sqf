#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_startPoliceStationCapture
 *
 * Server-only. Triggered when a player uses the "Capture Police
 * Station" addAction on the station flag. Starts a town-style
 * capture mini-game:
 *
 *   1. Validates -- station not already captured, not already in
 *      progress, caller alive.
 *   2. Creates an ELLIPSE capture circle (~50m radius) around the
 *      station, visible to all players for the duration.
 *   3. Dispatches reinforcements from the nearest other (non-
 *      captured) police station via BO_fnc_dispatchPoliceReinforcements.
 *   4. Installs a per-frame handler that fires every second. If the
 *      timer (BO_polCaptureSeconds, default 180s) elapses with the
 *      caller alive and inside the circle, the station is captured.
 *      Otherwise the capture fails: circle removed, reinforcements
 *      cancelled, state cleared.
 *
 * Params:
 *   0: STRING - town name
 *   1: STRING - caller UID
 */

if (!isServer) exitWith {};

params [["_town", "", [""]], ["_callerUID", "", [""]]];
if (_town isEqualTo "" || {_callerUID isEqualTo ""}) exitWith {};

private _stations = server getVariable ["BO_natoPoliceStations", []];
private _idx = _stations findIf { (_x select 0) isEqualTo _town };
if (_idx < 0) exitWith {};

private _entry = _stations select _idx;
if (_entry select 2) exitWith {};

private _activeKey = format ["BO_polcap_active_%1", _town];
if (missionNamespace getVariable [_activeKey, false]) exitWith {};

// Resolve caller -- need a player object for distance + alive checks.
private _callerIdx = allPlayers findIf { getPlayerUID _x isEqualTo _callerUID };
private _callerObj = if (_callerIdx >= 0) then { allPlayers select _callerIdx } else { objNull };
if (isNull _callerObj) exitWith {};

private _stationPos = _entry select 1;
private _captureRadius = 50;
private _captureSeconds = missionNamespace getVariable ["BO_polCaptureSeconds", 180];

// Capture circle marker -- ellipse, red, visible to all clients.
private _circleId = format ["BO_polcap_circle_%1", _town];
deleteMarker _circleId;
createMarker [_circleId, _stationPos];
_circleId setMarkerShape "ELLIPSE";
_circleId setMarkerSize [_captureRadius, _captureRadius];
_circleId setMarkerColor "ColorRed";
_circleId setMarkerBrush "Border";
_circleId setMarkerAlpha 0.7;

// Mark the in-progress flag so the action condition gates and the
// loop can recognise an active capture.
missionNamespace setVariable [_activeKey, true, true];
private _startKey   = format ["BO_polcap_start_%1", _town];
private _circleKey  = format ["BO_polcap_circleId_%1", _town];
private _callerKey  = format ["BO_polcap_callerUID_%1", _town];
missionNamespace setVariable [_startKey,   serverTime, true];
missionNamespace setVariable [_circleKey,  _circleId,  true];
missionNamespace setVariable [_callerKey,  _callerUID, true];

// Broadcast notify.
private _msg = format ["%1 is attempting to capture the police station at %2 -- hold the circle for %3 minutes!", name _callerObj, _town, round (_captureSeconds / 60)];
_msg remoteExec ["OT_fnc_notifyMinor", 0, false];
[AUDIT_ADMIN, _msg, [_town, _callerUID], _callerUID, name _callerObj] call BO_fnc_auditServer;

// Broadcast the screen-top progress bar to every connected client.
// The HUD PFH self-terminates when BO_polcap_active_<town> flips
// false (success or failure paths both clear it).
[_town, _captureSeconds] remoteExec ["BO_fnc_polCaptureHUD", 0, false];

// Reinforcements from a different station -- adds a wave of cops
// to actively contest the capture.
[_town, _stationPos] call BO_fnc_dispatchPoliceReinforcements;

// Capture watchdog PFH (1s tick).
private _pfh = [{
    params ["_args", "_pfhId"];
    _args params ["_town", "_callerUID", "_stationPos", "_captureRadius", "_captureSeconds"];

    private _activeKey = format ["BO_polcap_active_%1", _town];
    private _startKey  = format ["BO_polcap_start_%1",  _town];
    private _circleKey = format ["BO_polcap_circleId_%1", _town];
    if (!(missionNamespace getVariable [_activeKey, false])) exitWith {
        [_pfhId] call CBA_fnc_removePerFrameHandler;
    };

    // Every player inside the capture circle is wanted while the
    // mini-game runs. Civ-disguised players would otherwise hold the
    // circle unchallenged -- the whole point of capturing a police
    // station is fighting police, so the disguise is invalidated once
    // you commit to the capture. Re-asserted every tick so OT's
    // 30s hide timer can't clear the state while the player is still
    // standing in the ellipse. revealToNATO ensures immediate
    // engagement instead of waiting for the next unitSeen poll.
    {
        if (alive _x && {(_x distance2D _stationPos) <= _captureRadius} && {captive _x}) then {
            _x setCaptive false;
            [_x] call OT_fnc_revealToNATO;
        };
    } forEach allPlayers;

    private _start = missionNamespace getVariable [_startKey, serverTime];
    private _elapsed = serverTime - _start;

    private _callerIdx = allPlayers findIf { getPlayerUID _x isEqualTo _callerUID };
    private _caller = if (_callerIdx >= 0) then { allPlayers select _callerIdx } else { objNull };

    // Failure conditions.
    private _failed = false;
    private _failReason = "";
    if (isNull _caller) then { _failed = true; _failReason = "caller disconnected" };
    if (!_failed && {!alive _caller}) then { _failed = true; _failReason = "caller dead" };
    if (!_failed && {(_caller distance2D _stationPos) > _captureRadius}) then {
        // Brief grace -- allow 10s out of circle before failing.
        private _outKey = format ["BO_polcap_outSince_%1", _town];
        private _outSince = missionNamespace getVariable [_outKey, -1];
        if (_outSince < 0) then {
            missionNamespace setVariable [_outKey, serverTime, true];
        } else {
            if ((serverTime - _outSince) > 10) then {
                _failed = true; _failReason = "left the circle";
            };
        };
    } else {
        // Reset out-of-circle grace stamp.
        missionNamespace setVariable [format ["BO_polcap_outSince_%1", _town], -1, true];
    };

    if (_failed) exitWith {
        [_pfhId] call CBA_fnc_removePerFrameHandler;
        [_town, _failReason] call BO_fnc_failPoliceStationCapture;
    };

    // Success: timer elapsed with caller alive in circle.
    if (_elapsed >= _captureSeconds) exitWith {
        [_pfhId] call CBA_fnc_removePerFrameHandler;
        [_town] call BO_fnc_captureNATOPoliceStation;
    };
}, 1, [_town, _callerUID, _stationPos, _captureRadius, _captureSeconds]] call CBA_fnc_addPerFrameHandler;

missionNamespace setVariable [format ["BO_polcap_pfh_%1", _town], _pfh, true];
