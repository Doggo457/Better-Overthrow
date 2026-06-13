/*
 * Client-side wrapper for the factory dialog "Remove All" button.
 * Resolves the player's factory and routes to the server-auth
 * clear helper.
 */

params ["_qty"];

private _factory = OT_interactingWith;
if (isNull _factory || {(typeOf _factory) != OT_factory}) then {
    _factory = (getPosATL player) nearestObject OT_factory;
    if (!isNull _factory && {(player distance _factory) > 150}) then {
        _factory = objNull;
    };
};
if (isNull _factory) exitWith {};

[_factory] remoteExec ["BO_fnc_factoryQueueClearTarget", 2, false];

[{ [] call OT_fnc_factoryRefresh; }, [], 0.1] call CBA_fnc_waitAndExecute;
