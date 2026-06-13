#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_bankWithdraw
 *
 * Move money from bank to personal cash. 2% fee on standard ATMs,
 * 5% in NATO-controlled towns. No wanted-flag side effects.
 *
 * Params:
 *   0: SCALAR - amount
 */

params [["_amount", 0, [0]]];
if (_amount <= 0) exitWith {};

private _bank = player getVariable ["BO_bank", 0];
if (_amount > _bank) then { _amount = _bank };
if (_amount <= 0) exitWith { "Insufficient bank balance" call OT_fnc_notifyMinor };

// Determine fee based on the same context fn_atmDialog used: the
// shopkeeper NPC the player is standing next to (if any). Remote
// banking from ACE Self Interact has no nearby shopkeeper -> default
// 2% fee. Scanning for shopkeepers (not Land_CashDesk_F) keeps this
// in sync with fn_atmDialog's display.
private _nearShoppers = (player nearObjects ["CAManBase", 5]) select {
    _x getVariable ["shopcheck", false]
};
private _atmCtx = if (_nearShoppers isEqualTo []) then { objNull } else { _nearShoppers select 0 };
private _isNato = [_atmCtx] call BO_fnc_isNATOControlledATM;

private _feeRate = if (_isNato) then { 0.05 } else { 0.02 };
private _fee = round (_amount * _feeRate);
private _netCash = _amount - _fee;

// Personal cash is owned locally, so credit net amount locally.
private _cash = player getVariable ["money", 0];
player setVariable ["money", _cash + _netCash, true];

// MP race: BO_bank is authoritative server-side. Debit via delta call
// so concurrent writers (transfers, deposits) don't clobber each other.
private _uid = getPlayerUID player;
[_uid, -_amount, format ["Withdraw $%1 (fee $%2, NATO=%3)", _amount, _fee, _isNato]] remoteExec ["BO_fnc_bankAdjust", 2, false];

format ["Withdrew $%1 (Fee $%2; Balance: $%3)",
    [_netCash, 1, 0, true] call CBA_fnc_formatNumber,
    [_fee, 1, 0, true] call CBA_fnc_formatNumber,
    [_bank - _amount, 1, 0, true] call CBA_fnc_formatNumber
] call OT_fnc_notifyMinor;

[AUDIT_ATM,
 format ["Withdraw $%1 (fee $%2, NATO=%3)", _amount, _fee, _isNato],
 [_amount, _fee, "withdraw", _isNato]
] call BO_fnc_audit;
