#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_polCaptureHUD
 *
 * Client-side. Installs a screen-top progress bar showing capture
 * progress for an in-flight police station capture. The bar
 * auto-removes when the active flag (BO_polcap_active_<town>) flips
 * back to false (success or failure both clear it via the server-
 * side fns).
 *
 * Called via remoteExec from BO_fnc_startPoliceStationCapture with
 * target 0 so every player on the server sees the bar, matching the
 * town-capture convention where the campaign-level event is visible
 * to all.
 *
 * Params:
 *   0: STRING - town name
 *   1: SCALAR - capture duration in seconds
 */

if (!hasInterface) exitWith {};

params [["_town", "", [""]], ["_duration", 180, [0]]];
if (_town isEqualTo "") exitWith {};

// Tear down any prior bar -- avoids overlapping ctrls if two
// captures fire back-to-back or a previous one cleaned up late.
private _existingPfh = missionNamespace getVariable ["BO_polcap_hudPfh", -1];
if (_existingPfh >= 0) then {
    [_existingPfh] call CBA_fnc_removePerFrameHandler;
};

private _disp = findDisplay 46;
if (isNull _disp) exitWith {};

private _barIdc  = 9300;
private _textIdc = 9301;
{ ctrlDelete (_disp displayCtrl _x) } forEach [_barIdc, _textIdc];

// Progress bar (red fill on dark background) -- top center of screen.
private _bar = _disp ctrlCreate ["RscProgress", _barIdc];
_bar ctrlSetPosition [
    0.34 * safeZoneW + safeZoneX,
    0.08 * safeZoneH + safeZoneY,
    0.32 * safeZoneW,
    0.040 * safeZoneH
];
_bar ctrlSetTextColor [0.85, 0.15, 0.15, 1];
_bar progressSetPosition 0;
_bar ctrlCommit 0;

// Text overlay on top of the bar -- shows town, % and remaining time.
private _txt = _disp ctrlCreate ["RscStructuredText", _textIdc];
_txt ctrlSetPosition [
    0.34 * safeZoneW + safeZoneX,
    0.08 * safeZoneH + safeZoneY,
    0.32 * safeZoneW,
    0.040 * safeZoneH
];
_txt ctrlSetBackgroundColor [0, 0, 0, 0.35];
_txt ctrlCommit 0;

private _pfh = [{
    params ["_args", "_pfhId"];
    _args params ["_town", "_duration", "_barIdc", "_textIdc"];

    private _disp = findDisplay 46;
    private _active = missionNamespace getVariable [format ["BO_polcap_active_%1", _town], false];
    if (!_active || {isNull _disp}) exitWith {
        if (!isNull _disp) then {
            { ctrlDelete (_disp displayCtrl _x) } forEach [_barIdc, _textIdc];
        };
        [_pfhId] call CBA_fnc_removePerFrameHandler;
        missionNamespace setVariable ["BO_polcap_hudPfh", -1];
    };

    private _start = missionNamespace getVariable [format ["BO_polcap_start_%1", _town], serverTime];
    private _elapsed = serverTime - _start;
    private _pct = ((_elapsed / _duration) max 0) min 1;
    private _rem = (_duration - _elapsed) max 0;
    private _mins = floor (_rem / 60);
    private _secs = floor (_rem mod 60);
    private _secStr = if (_secs < 10) then { format ["0%1", _secs] } else { str _secs };

    private _bar = _disp displayCtrl _barIdc;
    private _txt = _disp displayCtrl _textIdc;
    if (!isNull _bar) then { _bar progressSetPosition _pct };
    if (!isNull _txt) then {
        private _line = format [
            "<t align='center' size='0.75' color='#ffffff' shadow='1'>Capturing Police: %1 -- %2%4 (%3:%5)</t>",
            _town, round (_pct * 100), _mins, "%", _secStr
        ];
        _txt ctrlSetStructuredText parseText _line;
    };
}, 0.5, [_town, _duration, _barIdc, _textIdc]] call CBA_fnc_addPerFrameHandler;

missionNamespace setVariable ["BO_polcap_hudPfh", _pfh];
