#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_installInsuranceKilledEH
 *
 * Install a server-side Killed EH on a vehicle that fires the insurance
 * payout when the vehicle dies. Idempotent -- flag-guarded so repeated
 * calls during save/load round-trips don't stack EHs.
 *
 * Uses addMPEventHandler ["MPKilled"]: a plain "Killed" EH only fires
 * where the vehicle is LOCAL at death, and a driven vehicle is local to
 * the driver's client -- so a server-added "Killed" never fires for
 * player-driven deaths on dedicated. MPKilled fires on every machine;
 * the isServer guard in the body keeps the payout server-only
 * (BO_fnc_bankAdjust is server-only).
 *
 * Params:
 *   0: OBJECT - vehicle to attach the EH to
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [["_veh", objNull, [objNull]]];

if (isNull _veh) exitWith {};
if (_veh getVariable ["BO_insuranceEHInstalled", false]) exitWith {};
_veh setVariable ["BO_insuranceEHInstalled", true];

_veh addMPEventHandler ["MPKilled", {
    params ["_unit", "_killer", "_instigator"];
    if (!isServer) exitWith {};
    if (!(_unit getVariable ["BO_insured", false])) exitWith {};
    if (_unit getVariable ["BO_insurancePaid", false]) exitWith {};
    _unit setVariable ["BO_insurancePaid", true, true];

    private _uid = _unit getVariable ["BO_insurancePayoutTarget", ""];
    private _value = _unit getVariable ["BO_insuranceValueAtPolicy", 0];
    private _payoutPct = ["bo_garage_insurance_payout_pct", 60] call BIS_fnc_getParamValue;
    private _payout = round (_value * (_payoutPct / 100));
    if (_uid isEqualTo "" || {_payout <= 0}) exitWith {};

    private _cls = typeOf _unit;
    [_uid, _payout, format ["Insurance payout: %1", _cls]] call BO_fnc_bankAdjust;

    private _auditMsg = format ["Insurance payout %1 -> uid=%2 ($%3)", _cls, _uid, _payout];
    [AUDIT_GARAGE, _auditMsg, [_cls, _uid, _payout, _value], _uid, ""] call BO_fnc_auditServer;

    private _idx = allPlayers findIf { getPlayerUID _x isEqualTo _uid };
    if (_idx >= 0) then {
        private _notify = format ["Insurance paid out $%1 for your %2", _payout, _cls];
        _notify remoteExec ["OT_fnc_notifyGood", owner (allPlayers select _idx), false];
    };
}];
