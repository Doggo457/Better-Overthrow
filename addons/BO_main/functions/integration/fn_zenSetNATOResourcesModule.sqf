#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetNATOResourcesModule
 *
 * Zen module: set the raw NATOresources budget directly. The existing
 * Set War Level module works in dial units (1 dial = 300 resources,
 * capped at 10/3000); this one takes the exact number, uncapped above,
 * for fine control over HAL's spending pool (package costs, garrison
 * convoys, interdiction all debit this ledger; the HUD dial and HAL's
 * WL-derived consistency both recompute from it on their next pass).
 *
 * Full-Zeus only by construction: module placement requires the Place
 * action, which the restricted (General) curator has at coef -1.
 *
 * Params:
 *   0: ARRAY  - placement position (unused, global setting)
 *   1: OBJECT - module logic
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _curResources = server getVariable ["NATOresources", 0];

[
    format ["Set NATO Resources (currently %1 -- budget only; WL is separate)", _curResources],
    [
        ["EDIT", "NATO Resources:", str _curResources]
    ],
    {
        params ["_result"];
        private _new = round (parseNumber (_result # 0));
        _new = _new max 0;
        server setVariable ["NATOresources", _new, true];
        [AUDIT_ADMIN, format ["Zeus set NATOresources to %1", _new], [_new], "", ""] call BO_fnc_auditServer;
        (format ["NATO resources set to %1 (budget only -- WL unchanged)", _new]) call OT_fnc_notifyMinor;
    },
    {},
    []
] call zen_dialog_fnc_create;
