#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetBankContext
 *
 * Right-click context menu callback (Zen). Opens a dialog to set the
 * target player's BO_bank balance (ATM funds).
 *
 * Params:
 *   0: OBJECT - target unit (hovered entity)
 */

params [["_target", objNull, [objNull]]];
if (!isPlayer _target) exitWith { false };

private _curBank = _target getVariable ["BO_bank", 0];

[
    format ["Set Bank Balance for %1 (currently $%2)", name _target, _curBank],
    [
        ["EDIT", "New bank balance:", str _curBank]
    ],
    {
        params ["_result", "_args"];
        _args params ["_target"];
        private _new = (parseNumber (_result # 0)) max 0;
        // BO_bank is server-authoritative (BO_fnc_bankAdjust is the
        // sole writer). Compute the delta and route through it so the
        // RMW is atomic with concurrent deposit/withdraw/transfer/
        // logistics writes, the floor-at-zero clamp applies, and an
        // AUDIT_ATM entry is produced. The previous "route to owner
        // client" pattern was wrong here -- the player never writes
        // BO_bank themselves; admin writes were racing the server.
        private _cur = _target getVariable ["BO_bank", 0];
        private _delta = _new - _cur;
        private _uid = getPlayerUID _target;
        if (_delta != 0) then {
            [_uid, _delta, format ["Zeus set bank to $%1", _new]] remoteExec ["BO_fnc_bankAdjust", 2, false];
        };
        [AUDIT_ADMIN, format ["Zeus set %1 bank to $%2", name _target, _new], [_uid, _new], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_target]
] call zen_dialog_fnc_create;
