#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_bankReceivePlayerTransfer
 *
 * Server-side receiver for player-to-player bank transfers.
 * Called via remoteExec from BO_fnc_bankTransferPlayer.
 *
 * Params:
 *   0: STRING - target UID
 *   1: SCALAR - net amount (fee already deducted by sender)
 */

SERVER_ONLY;

params [
    ["_targetUID", "", [""]],
    ["_amount", 0, [0]]
];

if (_targetUID isEqualTo "" || _amount <= 0) exitWith {};

// MP race: route credit through the authoritative adjuster so
// concurrent writers (the recipient's own deposits/withdrawals) can't
// clobber. bankAdjust handles online/offline routing internally.
[_targetUID, _amount, format ["Player transfer received $%1", _amount]] call BO_fnc_bankAdjust;

// Resolve live player (if any) purely for client-side notification.
private _target = objNull;
{ if (getPlayerUID _x isEqualTo _targetUID) exitWith { _target = _x }; } forEach allPlayers;

if (!isNull _target) then {
    format ["You received $%1 via bank transfer",
        [_amount, 1, 0, true] call CBA_fnc_formatNumber
    ] remoteExec ["OT_fnc_notifyMinor", _target, false];
};

[AUDIT_ATM,
 format ["Bank transfer received: $%1 to %2", _amount, _targetUID],
 [_amount, _targetUID],
 "",
 ""
] call BO_fnc_auditServer;
