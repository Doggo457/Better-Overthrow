#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garageCancelInsurance
 *
 * Server-auth: clear all insurance vars on a vehicle and refund a
 * configurable fraction of the original premium to the original payer's
 * bank. Only the policy holder (BO_insurancePayoutTarget) can cancel.
 *
 * Intended call site:
 *   [_veh, getPlayerUID player, name player]
 *       remoteExec ["BO_fnc_garageCancelInsurance", 2, false];
 *
 * Params:
 *   0: OBJECT - vehicle whose policy to cancel
 *   1: STRING - caller UID
 *   2: STRING - caller display name (audit)
 *
 * Returns: BOOL - true on success, false otherwise.
 */

SERVER_ONLY_RET(false);

params [
    ["_veh", objNull, [objNull]],
    ["_callerUID", "", [""]],
    ["_callerName", "", [""]]
];

if (isNull _veh) exitWith { false };
if (!(_veh getVariable ["BO_insured", false])) exitWith {
    "Vehicle is not insured" remoteExec ["OT_fnc_notifyMinor", remoteExecutedOwner, false];
    false
};

private _payoutTgt = _veh getVariable ["BO_insurancePayoutTarget", _callerUID];
if (_payoutTgt isNotEqualTo _callerUID) exitWith {
    "Only the original payer can cancel" remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    false
};

private _premium = _veh getVariable ["BO_insurancePremium", 0];
private _refundPct = ["bo_garage_insurance_refund_pct", 40] call BIS_fnc_getParamValue;
private _refund = round (_premium * (_refundPct / 100));

_veh setVariable ["BO_insured", false, true];
_veh setVariable ["BO_insurancePremium", 0, true];
_veh setVariable ["BO_insurancePayoutTarget", "", true];
_veh setVariable ["BO_insuranceValueAtPolicy", 0, true];

if (_refund > 0) then {
    [_callerUID, _refund, format ["Insurance cancelled refund: %1", typeOf _veh]] call BO_fnc_bankAdjust;
};

private _auditMsg = format ["Insurance cancelled (uid=%1 refund=%2)", _callerUID, _refund];
[AUDIT_GARAGE, _auditMsg, [typeOf _veh, _premium, _refund], _callerUID, _callerName] call BO_fnc_auditServer;

private _notify = format ["Insurance cancelled -- $%1 refunded", _refund];
_notify remoteExec ["OT_fnc_notifyMinor", remoteExecutedOwner, false];

true
