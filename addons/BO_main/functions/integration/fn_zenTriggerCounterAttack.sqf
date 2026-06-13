#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenTriggerCounterAttack
 *
 * Zen module: force a NATO counter-attack on the nearest resistance-
 * held (NATOabandoned) town. Wraps the existing OT_fnc_NATOCounterTown
 * (BO override) with a strength edit.
 *
 * Params (Zen module signature):
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _abandoned = server getVariable ["NATOabandoned", []];
if (_abandoned isEqualTo []) exitWith {
    "No resistance-held towns to counter-attack" call OT_fnc_notifyBad;
};

private _nearest = ["", 1e9];
{
    private _tp = server getVariable [_x, [0,0,0]];
    private _d = _position distance2D _tp;
    if (_d < (_nearest select 1)) then { _nearest = [_x, _d] };
} forEach _abandoned;

private _town = _nearest select 0;
if (_town isEqualTo "") exitWith {
    "No nearest resistance town" call OT_fnc_notifyBad;
};

[
    format ["NATO Counter-attack: %1", _town],
    [
        ["EDIT", "Strength (1=light, 5=heavy):", "3"]
    ],
    {
        params ["_result", "_args"];
        _args params ["_town"];
        private _strength = round (parseNumber (_result # 0));
        _strength = (_strength max 1) min 5;
        [_town, _strength] spawn OT_fnc_NATOCounterTown;
        private _msg = format ["Zeus triggered NATO counter-attack on %1 (strength %2)", _town, _strength];
        _msg call OT_fnc_notifyMinor;
        [AUDIT_ADMIN, _msg, [_town, _strength], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_town]
] call zen_dialog_fnc_create;
