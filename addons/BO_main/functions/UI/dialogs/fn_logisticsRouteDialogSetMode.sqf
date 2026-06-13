#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsRouteDialogSetMode
 *
 * Set the schedule mode on the Create/Edit Route dialog.
 *
 *   0 -> MANUAL
 *   1 -> INTERVAL
 *   2 -> TIMEOFDAY
 *
 * Also accepts the string mode name directly (so the open path can
 * pre-select from an existing route record without a translation
 * table). Updates the three mode buttons' visual state by appending
 * an asterisk to the selected one; the engine doesn't expose
 * pressed-toggle styling on RscOverthrowButton.
 *
 * Stores the canonical string on the display so submit can read it
 * back without re-deriving from the button row.
 */

params [["_modeArg", 0]];

private _modeStr = switch (true) do {
    case (_modeArg isEqualType ""): { _modeArg };
    case (_modeArg isEqualTo 1):    { "INTERVAL" };
    case (_modeArg isEqualTo 2):    { "TIMEOFDAY" };
    default                         { "MANUAL" };
};

private _disp = uiNamespace getVariable ["BO_dialog_logisticsRoute", displayNull];
if (isNull _disp) exitWith {};

_disp setVariable ["BO_routeScheduleMode", _modeStr];

private _label = {
    params ["_text", "_active"];
    if (_active) then { "* " + _text + " *" } else { _text }
};

(_disp displayCtrl 1620) ctrlSetText (["Manual",      _modeStr isEqualTo "MANUAL"]    call _label);
(_disp displayCtrl 1621) ctrlSetText (["Every N min", _modeStr isEqualTo "INTERVAL"]  call _label);
(_disp displayCtrl 1622) ctrlSetText (["Time of day", _modeStr isEqualTo "TIMEOFDAY"] call _label);

// Hide the schedule input row(s) that don't belong to the chosen mode.
// Manual = both hidden; Interval = show interval row only; TimeOfDay
// = show clock row only. Keeps the form focused on the inputs that
// actually matter for the active mode.
private _showInterval = _modeStr isEqualTo "INTERVAL";
private _showClock    = _modeStr isEqualTo "TIMEOFDAY";

// Interval row: label, edit, "min" suffix, 6 presets
{ (_disp displayCtrl _x) ctrlShow _showInterval } forEach [1106, 1404, 1107, 1630, 1631, 1632, 1633, 1634, 1635];

// TimeOfDay row: "At" label, hour edit, colon, minute edit
{ (_disp displayCtrl _x) ctrlShow _showClock } forEach [1108, 1405, 1109, 1406];
