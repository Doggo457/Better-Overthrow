#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetWarLevelModule
 *
 * Zen module: set the War Level directly. WL is the independent
 * aggression dial (server var BO_warLevel, 0-10) -- how hard NATO
 * pushes back -- and is NOT tied to the NATOresources budget (use the
 * separate "Set NATO Resources" module for the wallet).
 *
 * Drives: HAL tick consistency (acts on ~WL*10% of ticks), package WL
 * gates (armor 4+, CAS drone 4+, heavy armor 5+, air assault 5+,
 * manned air 6+), interdiction (4+), and the HUD dial color.
 *
 * Params:
 *   0: ARRAY  - placement position (unused, global setting)
 *   1: OBJECT - module logic
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _cur = round (server getVariable ["BO_warLevel", 1]);

[
    format ["Set War Level (currently %1/10 -- aggression, not budget)", _cur],
    [
        ["EDIT", "War Level (0-10):", str _cur]
    ],
    {
        params ["_result"];
        private _new = (round (parseNumber (_result # 0))) max 0 min 10;
        server setVariable ["BO_warLevel", _new, true];
        [AUDIT_ADMIN, format ["Zeus set War Level to %1/10", _new], [_new], "", ""] call BO_fnc_auditServer;
        (format ["War Level set to %1/10", _new]) call OT_fnc_notifyMinor;
    },
    {},
    []
] call zen_dialog_fnc_create;
