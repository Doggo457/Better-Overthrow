#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_bankTransferPlayer
 *
 * Transfer funds from this player's bank to another player's bank.
 * 1% fee. Faster than handing cash, doesn't require meeting up.
 *
 * Params:
 *   0: STRING - target UID
 *   1: SCALAR - amount
 */

params [
    ["_targetUID", "", [""]],
    ["_amount", 0, [0]]
];

if (_amount <= 0 || _targetUID isEqualTo "") exitWith {};

private _bank = player getVariable ["BO_bank", 0];
if (_amount > _bank) exitWith { "Insufficient bank balance" call OT_fnc_notifyMinor };

private _fee = round (_amount * 0.01);
private _net = _amount - _fee;

// BO_bank is server-authoritative. Route the sender debit through
// BO_fnc_bankAdjust so it can't lose a race against concurrent
// deposit/withdraw/logistics writes (also enforces the floor-at-zero
// clamp + writes a proper audit trail). The local _bank read above
// is purely a client-side affordability gate.
private _uid = getPlayerUID player;
[_uid, -_amount, format ["Transfer to %1 (gross $%2, fee $%3, net $%4)", _targetUID, _amount, _fee, _net]] remoteExec ["BO_fnc_bankAdjust", 2, false];

[_targetUID, _net] remoteExec ["BO_fnc_bankReceivePlayerTransfer", 2, false];

format ["Transferred $%1 to %2 (Fee $%3)",
    [_net, 1, 0, true] call CBA_fnc_formatNumber,
    players_NS getVariable [format ["name%1", _targetUID], _targetUID],
    [_fee, 1, 0, true] call CBA_fnc_formatNumber
] call OT_fnc_notifyMinor;

[AUDIT_ATM,
 format ["Transferred $%1 to %2 (fee $%3)", _net, _targetUID, _fee],
 [_amount, _targetUID, _fee, "transfer_player"]
] call BO_fnc_audit;
