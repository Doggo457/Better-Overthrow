#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetTownPolice
 *
 * Zen module: set police<town> count for the nearest town to the
 * module placement. Useful for testing stability mechanics that
 * gate on police presence.
 *
 * Params (Zen module signature):
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _town = _position call OT_fnc_nearestTown;
if (_town isEqualTo "") exitWith {
    "No nearest town" call OT_fnc_notifyBad;
};

private _cur = server getVariable [format ["police%1", _town], 0];

[
    format ["Set Police Count: %1 (currently %2)", _town, _cur],
    [
        ["EDIT", "Police (0-20):", str _cur]
    ],
    {
        params ["_result", "_args"];
        _args params ["_town"];
        private _new = round (parseNumber (_result # 0));
        _new = (_new max 0) min 20;
        server setVariable [format ["police%1", _town], _new, true];
        private _msg = format ["Zeus set police count at %1 to %2", _town, _new];
        _msg call OT_fnc_notifyMinor;
        [AUDIT_ADMIN, _msg, [_town, _new], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_town]
] call zen_dialog_fnc_create;
