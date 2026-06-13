#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsRouteDialogPreview
 *
 * Recompute the distance / travel time / fee line on the route
 * dialog. Called whenever the Source or Destination combo selection
 * changes.
 *
 * Resolves the selected containers via their stored ids
 * (lbData on the combo entries) and feeds them to
 * BO_fnc_logisticsTravelTime.
 */

private _disp = uiNamespace getVariable ["BO_dialog_logisticsRoute", displayNull];
if (isNull _disp) exitWith {};

private _cmbSrc = _disp displayCtrl 1400;
private _cmbDst = _disp displayCtrl 1401;
private _srcIdx = lbCurSel _cmbSrc;
private _dstIdx = lbCurSel _cmbDst;

private _preview = _disp displayCtrl 1110;

if (_srcIdx < 0 || _dstIdx < 0) exitWith {
    _preview ctrlSetStructuredText parseText "<t size='0.95' align='center' color='#bbbbbb'>Pick a source and destination to preview travel time and fee.</t>";
};

private _srcId = _cmbSrc lbData _srcIdx;
private _dstId = _cmbDst lbData _dstIdx;
private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;

if (isNull _src || isNull _dst) exitWith {
    _preview ctrlSetStructuredText parseText "<t size='0.95' align='center' color='#aa4444'>One of the selected containers is missing or offline.</t>";
};

if (_srcId isEqualTo _dstId) exitWith {
    _preview ctrlSetStructuredText parseText "<t size='0.95' align='center' color='#aa4444'>Source and destination must be different containers.</t>";
};

([_src, _dst] call BO_fnc_logisticsTravelTime) params ["_travelSec", "_fee", "_distM"];

private _mins = floor (_travelSec / 60);
private _secs = floor (_travelSec mod 60);
private _km = (_distM / 1000) toFixed 2;

private _msg = format [
    "<t size='0.95' align='center'>Distance: %1 km  |  Travel: %2m %3s  |  Fee: $%4 per trip</t>",
    _km, _mins, _secs, _fee
];
_preview ctrlSetStructuredText parseText _msg;
