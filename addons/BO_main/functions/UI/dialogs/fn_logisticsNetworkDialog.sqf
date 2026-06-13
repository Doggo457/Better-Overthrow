#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsNetworkDialog
 *
 * Open the Logistics dialog (BO_dialog_logistics, IDD 8050) and
 * handle its tab + action button events. Single entry point with a
 * mode string so the HPP's button actions can pivot without each
 * needing its own SQF function.
 *
 * Naming note: not `fn_logisticsDialog` because OT already ships a
 * vehicle-logistics dialog by that file name and we don't want to
 * override it.
 *
 * Modes:
 *   ""              - open with the Routes tab (default)
 *   "routes"        - switch to Routes tab
 *   "active"        - switch to Active tab
 *   "deleteConfirm" - prompt Yes/No via OT_fnc_playerDecision, then "delete"
 *   "delete"        - delete selected route (idx from arg 1)
 *   "pause"         - toggle pause on selected route
 *   "dispatch"      - fire selected route now
 *
 * Implementation: both listboxes are stacked at the same coords in
 * the HPP; ctrlShow toggles which is visible. The Routes-only action
 * row is also toggled on tab switch.
 *
 * Per-frame updater: while the dialog is open, refresh the Active
 * listbox once a second so the ETA counts down live. PFH id stored
 * on the display so it's cleaned up on close via Unload handler.
 *
 * Selection -> route mapping: lbData on each Routes row holds the
 * routeId, so we don't trust listbox row ordering.
 */

params [["_mode", "", [""]], ["_idx", -1, [0]]];

private _disp = uiNamespace getVariable ["BO_dialog_logistics", displayNull];

private _populateActive = {
    params ["_d"];
    private _activeLb = _d displayCtrl 1501;
    lbClear _activeLb;
    private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];
    private _now = serverTime;

    {
        _x params [
            "_deliveryId", "_routeId", "_startTime", "_etaTime",
            "_payload", "_srcId", "_dstId", "_ownerUID"
        ];
        private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
        private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
        private _srcLabel = if (isNull _src) then { "(missing)" } else { _src getVariable ["BO_logisticsLabel", "?"] };
        private _dstLabel = if (isNull _dst) then { "(missing)" } else { _dst getVariable ["BO_logisticsLabel", "?"] };

        ([_payload] call BO_fnc_logisticsPayloadSummary) params ["_totalUnits", "_payloadText"];

        private _remaining = (_etaTime - _now) max 0;
        private _mins = floor (_remaining / 60);
        private _secs = floor (_remaining mod 60);

        private _row = format ["%1  ->  %2   |   %3   |   ETA in %4m %5s",
            _srcLabel, _dstLabel, _payloadText, _mins, _secs];
        _activeLb lbAdd _row;
    } forEach _deliveries;
};

// Action handlers on an open dialog
switch (_mode) do {
    case "deleteConfirm": {
        // Destructive (deletes route + rolls back in-flight). Read selection
        // off the still-open dialog before OT_fnc_playerDecision closes it,
        // then re-open Logistics via waitAndExecute (choose-dialog button
        // runs `closeDialog 0; ... call OT_fnc_choiceMade;` synchronously).
        if (isNull _disp) exitWith {};
        if (_idx < 0) exitWith { "Select a route first" call OT_fnc_notifyMinor };
        private _routeId = lbData [1500, _idx];
        if (_routeId isEqualTo "") exitWith { "Couldn't read route id from selection" call OT_fnc_notifyMinor };
        private _rowText = lbText [1500, _idx];
        private _prompt = format [
            "<t align='center' size='1.0'>Delete this route?</t><br/><t align='center' size='0.85' color='#cccccc'>%1</t><br/><t align='center' size='0.85' color='#ff8888'>Any in-flight deliveries on this route will be rolled back.</t>",
            _rowText
        ];
        [
            _prompt,
            [
                "Yes, delete route",
                {
                    params ["_rid"];
                    [_rid, getPlayerUID player] remoteExec ["BO_fnc_logisticsDeleteRoute", 2, false];
                    [{ [""] call BO_fnc_logisticsNetworkDialog }, [], 0.5] call CBA_fnc_waitAndExecute;
                },
                _routeId
            ],
            [
                "Cancel",
                { [{ [""] call BO_fnc_logisticsNetworkDialog }, [], 0.1] call CBA_fnc_waitAndExecute }
            ]
        ] call OT_fnc_playerDecision;
    };
    case "delete": {
        if (isNull _disp) exitWith {};
        if (_idx < 0) exitWith { "Select a route first" call OT_fnc_notifyMinor };
        private _routeId = lbData [1500, _idx];
        if (_routeId isEqualTo "") exitWith { "Couldn't read route id from selection" call OT_fnc_notifyMinor };
        [_routeId, getPlayerUID player] remoteExec ["BO_fnc_logisticsDeleteRoute", 2, false];
        [{ [""] call BO_fnc_logisticsNetworkDialog }, [], 0.5] call CBA_fnc_waitAndExecute;
    };
    case "pause": {
        if (isNull _disp) exitWith {};
        if (_idx < 0) exitWith { "Select a route first" call OT_fnc_notifyMinor };
        private _routeId = lbData [1500, _idx];
        if (_routeId isEqualTo "") exitWith { "Couldn't read route id from selection" call OT_fnc_notifyMinor };
        [_routeId, getPlayerUID player] remoteExec ["BO_fnc_logisticsPauseRoute", 2, false];
        [{ [""] call BO_fnc_logisticsNetworkDialog }, [], 0.5] call CBA_fnc_waitAndExecute;
    };
    case "dispatch": {
        if (isNull _disp) exitWith {};
        if (_idx < 0) exitWith { "Select a route first" call OT_fnc_notifyMinor };
        private _routeId = lbData [1500, _idx];
        if (_routeId isEqualTo "") exitWith { "Couldn't read route id from selection" call OT_fnc_notifyMinor };
        "Dispatching..." call OT_fnc_notifyMinor;
        [_routeId, getPlayerUID player] remoteExec ["BO_fnc_logisticsDispatchNow", 2, false];
        [{ [""] call BO_fnc_logisticsNetworkDialog }, [], 0.5] call CBA_fnc_waitAndExecute;
    };
    case "routes": {
        if (isNull _disp) exitWith {};
        (_disp displayCtrl 1500) ctrlShow true;
        (_disp displayCtrl 1501) ctrlShow false;
        { (_disp displayCtrl _x) ctrlShow true } forEach [1610, 1611, 1612, 1613, 1614];
    };
    case "active": {
        if (isNull _disp) exitWith {};
        (_disp displayCtrl 1500) ctrlShow false;
        (_disp displayCtrl 1501) ctrlShow true;
        { (_disp displayCtrl _x) ctrlShow false } forEach [1610, 1611, 1612, 1613, 1614];
        [_disp] call _populateActive;
    };
};

if (_mode in ["delete", "deleteConfirm", "pause", "dispatch", "routes", "active"]) exitWith {};

// Full open path
closeDialog 0;
createDialog "BO_dialog_logistics";
_disp = uiNamespace getVariable ["BO_dialog_logistics", displayNull];
if (isNull _disp) exitWith {
    "Failed to open Logistics dialog" call OT_fnc_notifyMinor;
};

// Initial tab = Routes
(_disp displayCtrl 1500) ctrlShow true;
(_disp displayCtrl 1501) ctrlShow false;

// Populate Routes
private _routesLb = _disp displayCtrl 1500;
lbClear _routesLb;
private _routes = server getVariable ["BO_logisticsRoutes", []];

{
    _x params [
        "_routeId", "_ownerUID", "_srcId", "_dstId",
        "_items", "_qtyPerTrip",
        "_schedule", "_fee", "_paused", "_stats", "_skipIfEmpty"
    ];
    _schedule params [["_mode2", "MANUAL"], ["_intervalMin", 0], ["_timeOfDay", [0,0]], ["_lastFired", 0]];

    private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
    private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
    private _srcLabel = if (isNull _src) then { "(missing)" } else { _src getVariable ["BO_logisticsLabel", "(unnamed)"] };
    private _dstLabel = if (isNull _dst) then { "(missing)" } else { _dst getVariable ["BO_logisticsLabel", "(unnamed)"] };

    private _modeText = switch (_mode2) do {
        case "INTERVAL": { format ["Every %1m", _intervalMin] };
        case "TIMEOFDAY": {
            _timeOfDay params [["_th", 0], ["_tm", 0]];
            format ["At %1:%2", _th, [_tm, 2] call CBA_fnc_formatNumber]
        };
        default { "Manual" };
    };

    private _status = if (_paused) then { "PAUSED" } else { "Active" };
    private _itemsText = if (_items isEqualTo []) then { "All" } else { _items joinString "," };
    private _trips = _stats param [0, 0];

    private _row = format ["%1  ->  %2   |   %3   |   %4   |   %5   |   trips: %6   |   $%7",
        _srcLabel, _dstLabel, _modeText, _status, _itemsText, _trips, _fee];
    private _rowIdx = _routesLb lbAdd _row;
    _routesLb lbSetData [_rowIdx, _routeId];
    if (_paused) then { _routesLb lbSetColor [_rowIdx, [0.8, 0.4, 0.4, 1]] };
} forEach _routes;

// Populate Active (initial snapshot; the PFH refreshes per second below)
[_disp] call _populateActive;

// Per-frame countdown updater
private _pfhId = [{
    params ["_args", "_id"];
    _args params ["_d"];
    if (isNull _d) exitWith {
        [_id] call CBA_fnc_removePerFrameHandler;
    };

    private _activeLb = _d displayCtrl 1501;
    if (isNull _activeLb) exitWith {};
    if (!ctrlShown _activeLb) exitWith {};

    private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];
    private _now = serverTime;

    // Count mismatch: a delivery arrived or was dispatched since the last
    // tick. Rebuild the rows in place rather than recursing into the
    // 'active' case (which rerouted through the tab-switch path and ran
    // its side effects every second while a row was in flight).
    if (count _deliveries isNotEqualTo lbSize _activeLb) then {
        lbClear _activeLb;
        {
            _x params [
                "_deliveryId", "_routeId", "_startTime", "_etaTime",
                "_payload", "_srcId", "_dstId", "_ownerUID"
            ];
            private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
            private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
            private _srcLabel = if (isNull _src) then { "(missing)" } else { _src getVariable ["BO_logisticsLabel", "?"] };
            private _dstLabel = if (isNull _dst) then { "(missing)" } else { _dst getVariable ["BO_logisticsLabel", "?"] };

            ([_payload] call BO_fnc_logisticsPayloadSummary) params ["_totalUnits", "_payloadText"];

            private _remaining = (_etaTime - _now) max 0;
            private _mins = floor (_remaining / 60);
            private _secs = floor (_remaining mod 60);

            private _row = format ["%1  ->  %2   |   %3   |   ETA in %4m %5s",
                _srcLabel, _dstLabel, _payloadText, _mins, _secs];
            _activeLb lbAdd _row;
        } forEach _deliveries;
    } else {
        {
            _x params [
                "_deliveryId", "_routeId", "_startTime", "_etaTime",
                "_payload", "_srcId", "_dstId", "_ownerUID"
            ];
            private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
            private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
            private _srcLabel = if (isNull _src) then { "(missing)" } else { _src getVariable ["BO_logisticsLabel", "?"] };
            private _dstLabel = if (isNull _dst) then { "(missing)" } else { _dst getVariable ["BO_logisticsLabel", "?"] };

            ([_payload] call BO_fnc_logisticsPayloadSummary) params ["_totalUnits", "_payloadText"];

            private _remaining = (_etaTime - _now) max 0;
            private _mins = floor (_remaining / 60);
            private _secs = floor (_remaining mod 60);

            private _row = format ["%1  ->  %2   |   %3   |   ETA in %4m %5s",
                _srcLabel, _dstLabel, _payloadText, _mins, _secs];
            _activeLb lbSetText [_forEachIndex, _row];
        } forEach _deliveries;
    };
}, 1, [_disp]] call CBA_fnc_addPerFrameHandler;

_disp setVariable ["BO_logisticsPFH", _pfhId];
_disp displayAddEventHandler ["Unload", {
    params ["_d"];
    private _pfh = _d getVariable ["BO_logisticsPFH", -1];
    if (_pfh >= 0) then { [_pfh] call CBA_fnc_removePerFrameHandler };
}];
