#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconDialog
 *
 * Y-menu entry point for paid recon flights. Hijacks OT_dialog_jobs
 * (idd 8000, same pattern as BO_fnc_auditViewerDialog) -- the dialog
 * ships with a left-side listbox (IDC 1500), a right-side structured-
 * text details panel (IDC 1100), and a built-in X close button (1699).
 * The unused waypoint buttons (1600/1601) and picture (1200) are
 * hidden.
 *
 * Flow:
 *   1. Populate the listbox with every TOWN (Town: <name>),
 *      every REGION (Region: <name>) from objective + airport data,
 *      and a single MAP-WIDE row.
 *   2. LBSelChanged renders cost / est units / standing / eligibility
 *      into the right-side panel and toggles the Confirm button.
 *   3. Confirm: deduct cash client-side via OT_fnc_money, remoteExec
 *      BO_fnc_reconPurchase on the server, closeDialog 0.
 */

if (!hasInterface) exitWith {};

closeDialog 0;
createDialog "OT_dialog_jobs";
disableSerialization;

private _disp = findDisplay 8000;
if (isNull _disp) exitWith {
    "Recon dialog could not open" call OT_fnc_notifyBad;
};

// Hide controls that don't apply to recon picking.
ctrlShow [1200, false]; // picture
ctrlShow [1600, false]; // Set Waypoint
ctrlShow [1601, false]; // Clear Waypoint

private _lb = _disp displayCtrl 1500;
lbClear _lb;

private _myUID = getPlayerUID player;
private _active = server getVariable ["BO_activeRecon", []];
private _activeForMe = _active select { (_x select 0) isEqualTo _myUID };

// Towns.
{
    _x params ["_p", "_n"];
    private _idx = _lb lbAdd format ["Town: %1", _n];
    _lb lbSetData [_idx, format ["TOWN|%1", _n]];
} forEach OT_townData;

// Objectives + airports as "Region: <name>".
{
    _x params ["_p", "_n"];
    private _idx = _lb lbAdd format ["Region: %1", _n];
    _lb lbSetData [_idx, format ["REGION|%1", _n]];
} forEach (OT_objectiveData + OT_airportData);

// Map-wide premium.
private _idxMap = _lb lbAdd "Map-wide (premium)";
_lb lbSetData [_idxMap, "MAP|"];

_disp setVariable ["BO_reconActiveForMe", _activeForMe];

// Confirm button. IDC 1700 is unused by OT_dialog_jobs.
private _btnConfirm = _disp ctrlCreate ["RscOverthrowButton", 1700];
_btnConfirm ctrlSetText "Buy Recon";
_btnConfirm ctrlSetPosition [
    0.55 * safeZoneW + safeZoneX,
    0.80 * safeZoneH + safeZoneY,
    0.12 * safeZoneW,
    0.04 * safeZoneH
];
_btnConfirm ctrlEnable false;
_btnConfirm ctrlCommit 0;
_btnConfirm ctrlAddEventHandler ["ButtonClick", {
    params ["_ctrl"];
    private _d = ctrlParent _ctrl;
    private _lbi = _d displayCtrl 1500;
    private _sel = lbCurSel _lbi;
    if (_sel < 0) exitWith {};
    private _key = _lbi lbData _sel;
    private _parts = _key splitString "|";
    if (count _parts < 1) exitWith {};
    private _scope = _parts select 0;
    private _scopeKey = _parts param [1, ""];

    private _preview = [_scope, _scopeKey] call BO_fnc_reconCostPreview;
    _preview params ["_cost", "_est", "_standing"];

    private _minStand = missionNamespace getVariable ["BO_reconStandingMin", 50];
    if ((player getVariable ["money", 0]) < _cost) exitWith {
        "You cannot afford this recon" call OT_fnc_notifyBad;
    };
    if (_standing < _minStand) exitWith {
        private _msg = format ["Standing too low (%1 / need %2)", _standing, _minStand];
        _msg call OT_fnc_notifyBad;
    };

    // Deduct cash on the owning client (OT_fnc_money mutates locally).
    [-_cost] call OT_fnc_money;
    [getPlayerUID player, _scope, _scopeKey, _cost] remoteExec ["BO_fnc_reconPurchase", 2, false];
    closeDialog 0;
}];

// Selection handler: render details + toggle confirm button.
_lb ctrlSetEventHandler ["LBSelChanged", "
    params ['_ctrl', '_idx'];
    private _d = ctrlParent _ctrl;
    private _key = _ctrl lbData _idx;
    private _parts = _key splitString '|';
    if (count _parts < 1) exitWith {};
    private _scope = _parts select 0;
    private _scopeKey = _parts param [1, ''];

    private _preview = [_scope, _scopeKey] call BO_fnc_reconCostPreview;
    _preview params ['_cost', '_est', '_standing'];

    private _minStand = missionNamespace getVariable ['BO_reconStandingMin', 50];
    private _durMin   = missionNamespace getVariable ['BO_reconDurationMinutes', 10];

    private _active  = _d getVariable ['BO_reconActiveForMe', []];
    private _overlap = (_active findIf { ((_x select 1) isEqualTo _scope) && {(_x select 2) isEqualTo _scopeKey} }) != -1;
    private _afford  = (player getVariable ['money', 0]) >= _cost;
    private _standOK = _standing >= _minStand;
    private _eligible = _afford && _standOK && !_overlap;

    private _statusColor = if (_eligible) then { '88ff88' } else { 'ff8888' };
    private _statusText = if (_overlap) then {
        'Recon already active in this area'
    } else {
        if (!_afford) then {
            'Cannot afford'
        } else {
            if (!_standOK) then { 'Standing too low' } else { 'Ready to purchase' }
        }
    };

    private _label = if (_scopeKey isEqualTo '') then { _scope } else { format ['%1 %2', _scope, _scopeKey] };

    private _txt = format [
        '<t size=''1.0'' align=''left''>%1</t><br/><br/><t size=''0.8''>Cost: $%2</t><br/><t size=''0.8''>Est. enemy units: ~%3</t><br/><t size=''0.8''>Standing: %4 (need %5)</t><br/><t size=''0.8''>Duration: %6 in-game minutes</t><br/><br/><t size=''0.8'' color=''#%7''>%8</t>',
        _label, _cost, _est, _standing, _minStand, _durMin, _statusColor, _statusText
    ];

    (_d displayCtrl 1100) ctrlSetStructuredText parseText _txt;
    (_d displayCtrl 1700) ctrlEnable _eligible;
"];

// Open with selection on first row so the details panel populates.
if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
