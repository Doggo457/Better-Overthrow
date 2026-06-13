#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsRouteDialog
 *
 * Open the Create / Edit Route sub-dialog (BO_dialog_logisticsRoute,
 * IDD 8051) and populate its controls.
 *
 * Modes:
 *   "create" -- empty form, defaults to Manual schedule
 *   "edit"   -- pre-fill from the route at routeIdx in the Routes
 *               listbox (lbData [1500, idx] = routeId)
 *
 * Dialog state (stored on the display via setVariable):
 *   BO_routeEditingId    STRING - "" for create, routeId for edit
 *   BO_routeScheduleMode STRING - "MANUAL" | "INTERVAL" | "TIMEOFDAY"
 *   BO_routeSkipIfEmpty  BOOL
 *
 * Source/Dest combo entries: each lb item stores containerId via
 * lbSetData so we don't have to re-resolve by label string when the
 * user submits.
 */

params [["_mode", "create", [""]], ["_routeIdx", -1, [0]]];

private _editingId = "";
private _route = [];

if (_mode isEqualTo "edit") then {
    if (_routeIdx < 0) exitWith {
        "Select a route first" call OT_fnc_notifyMinor;
    };
    private _routesDisp = uiNamespace getVariable ["BO_dialog_logistics", displayNull];
    if (isNull _routesDisp) exitWith {};
    _editingId = (_routesDisp displayCtrl 1500) lbData _routeIdx;
    if (_editingId isEqualTo "") exitWith {};

    private _routes = server getVariable ["BO_logisticsRoutes", []];
    private _idx2 = _routes findIf { (_x select 0) isEqualTo _editingId };
    if (_idx2 < 0) exitWith {};
    _route = _routes select _idx2;

    // Permission check
    private _ownerUID = _route select 1;
    private _generals = server getVariable ["generals", []];
    if !((getPlayerUID player isEqualTo _ownerUID) || (getPlayerUID player in _generals)) exitWith {
        "Only the route creator (or a General) can edit this route" call OT_fnc_notifyMinor;
    };
};

closeDialog 0;
createDialog "BO_dialog_logisticsRoute";
private _disp = uiNamespace getVariable ["BO_dialog_logisticsRoute", displayNull];
if (isNull _disp) exitWith {};

(_disp displayCtrl 1100) ctrlSetStructuredText parseText (
    if (_mode isEqualTo "edit") then {
        "<t size='1.4' align='center'>EDIT ROUTE</t>"
    } else {
        "<t size='1.4' align='center'>CREATE ROUTE</t>"
    }
);

// Populate Source + Destination combos
private _tagged = [] call BO_fnc_logisticsListTagged;
private _cmbSrc = _disp displayCtrl 1400;
private _cmbDst = _disp displayCtrl 1401;
lbClear _cmbSrc;
lbClear _cmbDst;

{
    _x params ["_id", "_label", "_role", "_ownerUID", "_obj"];
    private _townName = if (isNull _obj) then { "?" } else { (_obj call OT_fnc_nearestTown) };
    private _entry = format ["%1 (%2)", _label, _townName];

    if (_role isEqualTo "SOURCE") then {
        private _i = _cmbSrc lbAdd _entry;
        _cmbSrc lbSetData [_i, _id];
    };
    if (_role isEqualTo "DEST") then {
        private _i = _cmbDst lbAdd _entry;
        _cmbDst lbSetData [_i, _id];
    };
} forEach _tagged;

// Defaults (or pre-fill from edit)
private _initMode = "MANUAL";
private _initSkip = true;

if (_mode isEqualTo "edit") then {
    _route params [
        "_routeId", "_ownerUID", "_srcId", "_dstId",
        "_items", "_qtyPerTrip",
        "_schedule", "_fee", "_paused", "_stats", "_skipIfEmpty"
    ];
    _schedule params [["_sMode", "MANUAL"], ["_intervalMin", 30], ["_timeOfDay", [12, 0]], ["_lastFired", 0]];

    // Select source/dest in their combos
    private _srcCount = lbSize _cmbSrc;
    for "_i" from 0 to _srcCount - 1 do {
        if (_cmbSrc lbData _i isEqualTo _srcId) then { _cmbSrc lbSetCurSel _i };
    };
    private _dstCount = lbSize _cmbDst;
    for "_i" from 0 to _dstCount - 1 do {
        if (_cmbDst lbData _i isEqualTo _dstId) then { _cmbDst lbSetCurSel _i };
    };

    ctrlSetText [1402, _items joinString ","];
    ctrlSetText [1403, str _qtyPerTrip];
    ctrlSetText [1404, str _intervalMin];

    _timeOfDay params [["_th", 12], ["_tm", 0]];
    ctrlSetText [1405, str _th];
    ctrlSetText [1406, str _tm];

    _initMode = _sMode;
    _initSkip = _skipIfEmpty;
} else {
    if (lbSize _cmbSrc > 0) then { _cmbSrc lbSetCurSel 0 };
    if (lbSize _cmbDst > 0) then { _cmbDst lbSetCurSel 0 };
};

_disp setVariable ["BO_routeEditingId", _editingId];
_disp setVariable ["BO_routeScheduleMode", _initMode];
_disp setVariable ["BO_routeSkipIfEmpty", _initSkip];

[_initMode] call BO_fnc_logisticsRouteDialogSetMode;

// Set the skip-toggle button text directly to match _initSkip
// without round-tripping through the toggle handler.
(_disp displayCtrl 1623) ctrlSetText (
    if (_initSkip) then { "Skip if source empty: ON" } else { "Skip if source empty: OFF" }
);

[] call BO_fnc_logisticsRouteDialogPreview;
