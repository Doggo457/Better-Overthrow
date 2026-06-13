#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_atmDialog
 *
 * Open the ATM dialog. Lets the player:
 *   - Deposit personal cash to bank
 *   - Withdraw from bank (2% fee, higher in NATO towns)
 *   - Transfer to another player's bank
 *
 * Implementation reuses OT_fnc_playerDecision for the option list.
 * (A purpose-built BO_dialog_atm dialog isn't viable until BO_main
 * ships a config.cpp -- OT's `config.bin` is precompiled and ignores
 * .hpp source we add, so for now we ride OT's existing dialog stack.)
 *
 * Params:
 *   0: OBJECT - the ATM object (used for context-aware fee calculation)
 */

params [["_atm", objNull, [objNull]]];

private _bank = call BO_fnc_getBankBalance;
private _isNatoControlled = [_atm] call BO_fnc_isNATOControlledATM;
private _baseFeeRate = 0.02;
private _feeRate = if (_isNatoControlled) then { 0.05 } else { _baseFeeRate };

private _options = [];

_options pushBack format ["<t align='center' size='1.1'>ATM</t><br/><t align='center' size='0.7'>Balance: $%1</t><br/><t align='center' size='0.7'>Withdraw fee: %2%3</t>",
    [_bank, 1, 0, true] call CBA_fnc_formatNumber,
    round (_feeRate * 100),
    "%"];

_options pushBack [
    "Deposit cash",
    {
        OT_inputHandler = {
            private _input = ctrlText 1400;
            // RULE 0: raw hint replaced with themed notification
            if (count _input > 64) exitWith { "Invalid amount" call OT_fnc_notifyBad };
            private _val = parseNumber _input;
            if (_val > 0) then { [_val] call BO_fnc_bankDeposit };
        };
        ["How much to deposit?", player getVariable ["money", 100]] call OT_fnc_inputDialog;
    }
];

_options pushBack [
    "Withdraw to cash",
    {
        OT_inputHandler = {
            private _input = ctrlText 1400;
            // RULE 0: raw hint replaced with themed notification
            if (count _input > 64) exitWith { "Invalid amount" call OT_fnc_notifyBad };
            private _val = parseNumber _input;
            if (_val > 0) then { [_val] call BO_fnc_bankWithdraw };
        };
        ["How much to withdraw?", 100] call OT_fnc_inputDialog;
    }
];

_options pushBack [
    "Transfer to player",
    {
        // Pick recipient first.
        private _opts = [];
        {
            if (_x isNotEqualTo player) then {
                _opts pushBack [
                    name _x,
                    {
                        // Closures don't capture local _vars across the UI boundary
                        // (OT_inputHandler is invoked later by the input dialog's OK
                        // button via the global namespace, so _targetUID would be
                        // nil inside it). Stash on missionNamespace instead.
                        missionNamespace setVariable ["BO_atmTransferTargetUID", getPlayerUID _this];
                        OT_inputHandler = {
                            private _input = ctrlText 1400;
                            private _val = parseNumber _input;
                            private _uid = missionNamespace getVariable ["BO_atmTransferTargetUID", ""];
                            if (_val > 0 && {_uid isNotEqualTo ""}) then {
                                [_uid, _val] call BO_fnc_bankTransferPlayer;
                            };
                        };
                        ["How much to transfer?", 100] call OT_fnc_inputDialog;
                    },
                    _x
                ];
            };
        } forEach allPlayers;
        _opts pushBack ["Cancel", {}];
        _opts call OT_fnc_playerDecision;
    }
];

_options pushBack ["Cancel", {}];
_options call OT_fnc_playerDecision;
