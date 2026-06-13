#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsRouteDialogSubmit
 *
 * Collect form state, validate, then either create a new route or
 * (for edit mode) delete-then-recreate the existing one. We don't
 * have a separate update remote -- edit is just delete + create,
 * which keeps the server side simple and atomic.
 *
 * On success closes the dialog and re-opens the main Logistics
 * dialog so the new/edited route shows up immediately.
 */

private _disp = uiNamespace getVariable ["BO_dialog_logisticsRoute", displayNull];
if (isNull _disp) exitWith {};

private _editingId = _disp getVariable ["BO_routeEditingId", ""];
private _mode      = _disp getVariable ["BO_routeScheduleMode", "MANUAL"];
private _skip      = _disp getVariable ["BO_routeSkipIfEmpty", true];

private _cmbSrc = _disp displayCtrl 1400;
private _cmbDst = _disp displayCtrl 1401;
private _srcIdx = lbCurSel _cmbSrc;
private _dstIdx = lbCurSel _cmbDst;

if (_srcIdx < 0) exitWith { "Pick a source container" call OT_fnc_notifyMinor };
if (_dstIdx < 0) exitWith { "Pick a destination container" call OT_fnc_notifyMinor };

private _srcId = _cmbSrc lbData _srcIdx;
private _dstId = _cmbDst lbData _dstIdx;
if (_srcId isEqualTo _dstId) exitWith {
    "Source and destination must differ" call OT_fnc_notifyMinor;
};

// Items: comma-separated, trimmed, blanks dropped
private _itemsRaw = ctrlText (_disp displayCtrl 1402);
private _items = [];
{
    private _t = _x;
    while { _t select [0,1] isEqualTo " " } do { _t = _t select [1] };
    while { _t select [count _t - 1] isEqualTo " " } do { _t = _t select [0, count _t - 1] };
    if (_t isNotEqualTo "") then { _items pushBack _t };
} forEach (_itemsRaw splitString ",");

// Split empty (= "move all") from explicit zero (user error). parseNumber
// on either returns 0, so we must inspect the raw text first.
private _qtyText = ctrlText (_disp displayCtrl 1403);
private _qty = if (_qtyText isEqualTo "") then {
    -1
} else {
    private _n = parseNumber _qtyText;
    if (_n <= 0) exitWith {
        "Quantity must be positive" call OT_fnc_notifyBad;
        nil
    };
    _n
};
if (isNil "_qty") exitWith {};

private _intervalMin = parseNumber (ctrlText (_disp displayCtrl 1404));
if (_intervalMin <= 0) then { _intervalMin = 60 };

// TIMEOFDAY: empty hour/minute would parseNumber to 0 and silently fire at
// midnight. Reject so the player notices instead of getting a surprise
// run at 00:00 in-game.
private _hhText = ctrlText (_disp displayCtrl 1405);
private _mmText = ctrlText (_disp displayCtrl 1406);
if (_mode isEqualTo "TIMEOFDAY" && { _hhText isEqualTo "" || { _mmText isEqualTo "" } }) exitWith {
    "Enter both hour and minute for Time of Day" call OT_fnc_notifyBad;
};
private _hh = parseNumber _hhText;
private _mm = parseNumber _mmText;
if (_hh < 0) then { _hh = 0 };
if (_hh > 23) then { _hh = 23 };
if (_mm < 0) then { _mm = 0 };
if (_mm > 59) then { _mm = 59 };

// Fee comes from the live preview (distance-based). Resolve once
// for the validated source/dest pair.
private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
if (isNull _src || isNull _dst) exitWith {
    "One of the selected containers is missing" call OT_fnc_notifyMinor;
};
([_src, _dst] call BO_fnc_logisticsTravelTime) params ["_travelSec", "_fee"];

private _schedule = [_mode, _intervalMin, [_hh, _mm]];

private _payload = [
    getPlayerUID player,
    _srcId,
    _dstId,
    _items,
    _qty,
    _schedule,
    _fee,
    _skip
];

if (_editingId isNotEqualTo "") then {
    [_editingId, getPlayerUID player] remoteExec ["BO_fnc_logisticsDeleteRoute", 2, false];
};

[_payload] remoteExec ["BO_fnc_logisticsCreateRoute", 2, false];

closeDialog 0;
[{ [] call BO_fnc_logisticsNetworkDialog }, [], 0.5] call CBA_fnc_waitAndExecute;
