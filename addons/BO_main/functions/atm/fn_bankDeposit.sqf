#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_bankDeposit
 *
 * Move money from personal cash to bank. No fee on deposit.
 *
 * Params:
 *   0: SCALAR - amount
 */

params [["_amount", 0, [0]]];
if (_amount <= 0) exitWith {};

private _cash = player getVariable ["money", 0];
if (_amount > _cash) then { _amount = _cash };
if (_amount <= 0) exitWith { "No funds to deposit" call OT_fnc_notifyMinor };

// Personal cash is owned by the local client, so debit it locally.
private _bank = player getVariable ["BO_bank", 0];
player setVariable ["money", _cash - _amount, true];

// MP race: BO_bank is now authoritative server-side. Send the delta
// through BO_fnc_bankAdjust so concurrent writers don't clobber.
private _uid = getPlayerUID player;
[_uid, _amount, format ["Deposit $%1", _amount]] remoteExec ["BO_fnc_bankAdjust", 2, false];

format ["Deposited $%1 (Balance: $%2)",
    [_amount, 1, 0, true] call CBA_fnc_formatNumber,
    [_bank + _amount, 1, 0, true] call CBA_fnc_formatNumber
] call OT_fnc_notifyMinor;

[AUDIT_ATM,
 format ["Deposit $%1", _amount],
 [_amount, "deposit"]
] call BO_fnc_audit;
