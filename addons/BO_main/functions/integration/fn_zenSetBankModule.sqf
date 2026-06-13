#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSetBankModule
 *
 * Zen module: set the nearest player's BO_bank balance (ATM funds).
 *
 * Params:
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic
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
        // BO_bank is server-authoritative -- route through bankAdjust
        // so the RMW is atomic with concurrent deposit/withdraw/
        // transfer/logistics writes and the floor-at-zero clamp +
        // audit trail apply. See zenSetBankContext for the full
        // rationale.
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
