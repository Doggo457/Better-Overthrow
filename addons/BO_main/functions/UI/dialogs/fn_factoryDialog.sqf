/*
 * fn_factoryDialog (BO override of OT_fnc_factoryDialog)
 *
 * Multi-factory: resolves the active factory from OT_interactingWith
 * (set by OT_fnc_manageArea when the dialog is opened) with a
 * fallback to the nearest OT_factory within 150m. Sets that object
 * as OT_interactingWith so the queue-mutator wrappers and the
 * refresh function read the same factory.
 *
 * Blueprints remain a global pool (server var GEURblueprints) --
 * any factory can produce any unlocked blueprint. Only the queue
 * and producing state are per-factory.
 */

private _factory = OT_interactingWith;
if (isNull _factory || {(typeOf _factory) != OT_factory}) then {
    _factory = (getPosATL player) nearestObject OT_factory;
    if (!isNull _factory && {(player distance _factory) > 150}) then {
        _factory = objNull;
    };
};

if (isNull _factory) exitWith {
    "No factory nearby" remoteExec ["OT_fnc_notifyMinor", 0, false];
};

// Pin OT_interactingWith for the duration of this dialog session so
// every button action (+1/+10/+100, Remove, Remove All, the refresh
// onLBSelChanged) reads the same factory.
OT_interactingWith = _factory;

createDialog 'OT_dialog_factory';

private _cursel = lbCurSel 1500;
lbClear 1500;
private _done = [];

{
    if (isClass (configFile >> "CfgWeapons" >> _x)) then {
        _x = [_x] call BIS_fnc_baseWeapon;
        if (_x in _done) then { continue }; // base weapons may be duplicates
    };

    _done pushBack _x;

    (_x call OT_fnc_getClassDisplayInfo) params ["_pic", "_name"];

    private _idx = lbAdd [1500, format ["%1", _name]];
    lbSetPicture [1500, _idx, _pic];
    lbSetData [1500, _idx, _x];
} forEach (server getVariable ["GEURblueprints", []]);

if (_cursel >= count _done) then { _cursel = 0 };
lbSetCurSel [1500, _cursel];

[] call OT_fnc_factoryRefresh;
