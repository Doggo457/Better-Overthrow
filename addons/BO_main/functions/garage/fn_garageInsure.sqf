#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garageInsure
 *
 * Server-auth: charge an insurance premium against the player's bank,
 * mark the vehicle BO_insured, set payout target, install the Killed
 * EH if not already installed.
 *
 * Intended call site:
 *   [_veh, getPlayerUID player, name player]
 *       remoteExec ["BO_fnc_garageInsure", 2, false];
 *
 * Params:
 *   0: OBJECT - vehicle to insure
 *   1: STRING - caller UID (also the payout target)
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

if (isNull _veh || {!alive _veh}) exitWith { false };
if (_veh getVariable ["BO_insured", false]) exitWith {
    "Vehicle is already insured" remoteExec ["OT_fnc_notifyMinor", remoteExecutedOwner, false];
    false
};

private _cls = typeOf _veh;
private _priceTuple = [_cls] call BO_fnc_resolvePrice;
private _baseVal = (_priceTuple select 0) max 500;
private _premiumPct = ["bo_garage_insurance_premium_pct", 15] call BIS_fnc_getParamValue;
private _premium = round (_baseVal * (_premiumPct / 100));

// Read current bank balance for an upfront affordability check (live
// player path overrides offline path -- avoids a needless attribute
// lookup for the common case).
private _bank = [_callerUID, "BO_bank", 0] call OT_fnc_getOfflinePlayerAttribute;
private _idx = allPlayers findIf { getPlayerUID _x isEqualTo _callerUID };
if (_idx >= 0) then {
    _bank = (allPlayers select _idx) getVariable ["BO_bank", 0];
};

if (_bank < _premium) exitWith {
    private _failMsg = format ["Insufficient bank funds: need $%1", _premium];
    _failMsg remoteExec ["OT_fnc_notifyBad", remoteExecutedOwner, false];
    false
};

[_callerUID, -_premium, format ["Insurance premium: %1", _cls]] call BO_fnc_bankAdjust;

_veh setVariable ["BO_insured", true, true];
_veh setVariable ["BO_insurancePremium", _premium, true];
_veh setVariable ["BO_insurancePayoutTarget", _callerUID, true];
_veh setVariable ["BO_insuranceValueAtPolicy", _baseVal, true];
_veh setVariable ["OT_forceSaveUnowned", true, true];
[_veh] call BO_fnc_installInsuranceKilledEH;

private _auditMsg = format ["Insured %1 (uid=%2 premium=%3 value=%4)", _cls, _callerUID, _premium, _baseVal];
[AUDIT_GARAGE, _auditMsg, [_cls, _premium, _baseVal], _callerUID, _callerName] call BO_fnc_auditServer;

private _notify = format ["Vehicle insured (premium $%1)", _premium];
_notify remoteExec ["OT_fnc_notifyGood", remoteExecutedOwner, false];

true
