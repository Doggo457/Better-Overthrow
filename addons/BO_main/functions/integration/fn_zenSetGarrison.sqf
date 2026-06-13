#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetGarrison
 *
 * Zen module: set garrison<base> count for the nearest NATO objective
 * (objective or airport, whichever is closer). Useful for testing
 * nighttime sabotage effects, depletion-driven reinforcement
 * triggers, and recon-base persistence.
 *
 * Params (Zen module signature):
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _bases = (OT_objectiveData + OT_airportData);
if (_bases isEqualTo []) exitWith {
    "No NATO bases on this map" call OT_fnc_notifyBad;
};

private _nearest = ["", 1e9];
{
    _x params ["_bp", "_bn"];
    private _d = _position distance2D _bp;
    if (_d < (_nearest select 1)) then { _nearest = [_bn, _d] };
} forEach _bases;
private _baseName = _nearest select 0;
if (_baseName isEqualTo "") exitWith {
    "No nearest base" call OT_fnc_notifyBad;
};

private _cur = server getVariable [format ["garrison%1", _baseName], 0];

[
    format ["Set Garrison: %1 (currently %2)", _baseName, _cur],
    [
        ["EDIT", "Garrison count (0-40):", str _cur]
    ],
    {
        params ["_result", "_args"];
        _args params ["_baseName"];
        private _new = round (parseNumber (_result # 0));
        _new = (_new max 0) min 40;
        server setVariable [format ["garrison%1", _baseName], _new, true];
        private _msg = format ["Zeus set garrison at %1 to %2", _baseName, _new];
        _msg call OT_fnc_notifyMinor;
        [AUDIT_ADMIN, _msg, [_baseName, _new], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_baseName]
] call zen_dialog_fnc_create;
