/*
 * Client-side wrapper for the factory dialog "Remove" button.
 * Reads the blueprints listbox selection (IDC 1500 -- matches the
 * legacy single-factory wrapper; the historical IDC choice is
 * preserved to avoid scope creep), resolves the player's factory
 * the same way fn_factoryQueueAdd does, then routes the index
 * through the server-auth target helper.
 */

params ["_qty"];

private _idx = lbCurSel 1500;
if (_idx isEqualTo -1) exitWith {};

private _factory = OT_interactingWith;
if (isNull _factory || {(typeOf _factory) != OT_factory}) then {
    _factory = (getPosATL player) nearestObject OT_factory;
    if (!isNull _factory && {(player distance _factory) > 150}) then {
        _factory = objNull;
    };
};
if (isNull _factory) exitWith {};

[_factory, _idx] remoteExec ["BO_fnc_factoryQueueRemoveTarget", 2, false];

[{ [] call OT_fnc_factoryRefresh; }, [], 0.1] call CBA_fnc_waitAndExecute;
