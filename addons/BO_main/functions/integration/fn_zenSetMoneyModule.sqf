#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetMoneyModule
 *
 * Zen custom-module callback: drag the module onto the map, drop near
 * a player, this dialog opens to set that player's personal cash.
 *
 * Mirrors OT_fnc_zenSetMoney (which is a right-click context action)
 * but uses the [position, logic] module-placement signature so it
 * shows up in Zen's Modules ("M") tab as well.
 *
 * Params:
 *   0: ARRAY  - position the module was placed
 *   1: OBJECT - the module logic entity (deleted after use)
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _target = objNull;
private _dist = 1e9;
{
    if (alive _x && {isPlayer _x}) then {
        private _d = _x distance2D _position;
        if (_d < _dist) then { _dist = _d; _target = _x };
    };
} forEach allPlayers;

if (isNull _target) exitWith {
    "No player found near module placement" call OT_fnc_notifyMinor;
};

private _curMoney = _target getVariable ["money", 0];

[
    format ["Set Money for %1 (currently $%2)", name _target, _curMoney],
    [
        ["EDIT", "New cash amount:", str _curMoney]
    ],
    {
        params ["_result", "_args"];
        _args params ["_target"];
        private _new = (parseNumber (_result # 0)) max 0;
        // Direct broadcast -- matches OT_fnc_zenSetMoney's sibling
        // pattern. setVariable with broadcast=true propagates globally
        // and is JIP-persistent regardless of caller locality; the
        // previous "remoteExec to owner" pattern added an avoidable
        // hop and would drop the write entirely if the target
        // disconnected mid-flight.
        _target setVariable ["money", _new, true];
        [AUDIT_ADMIN, format ["Zeus set %1 money to $%2", name _target, _new], [getPlayerUID _target, _new], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_target]
] call zen_dialog_fnc_create;
