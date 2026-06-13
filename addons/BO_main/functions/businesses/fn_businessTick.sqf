#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_businessTick
 *
 * Advance one production tick for _business (= one in-game hour).
 *
 * Per-tick work, with state on the building:
 *   1. Look up type spec from BO_businessTypes:
 *        [_inputCls, _outputCls, _outputPerHr, _employees]
 *   2. Pay wages: _employees * WAGE-per-hr from resistance funds.
 *      Insufficient funds -> notify "unable to pay wages at <type>"
 *      (mirrors GUERLoop's behavior) and skip production this tick.
 *   3. Ensure the I/O crate exists (rebind or spawn).
 *   4. If _inputCls != "":
 *        - Scan nearby cargo containers for _inputCls
 *        - Consume up to _outputPerHr units
 *        - Output = the count actually consumed
 *      Else:
 *        - Output = _outputPerHr (no input gate)
 *   5. Deposit output into the I/O crate via addItemCargoGlobal.
 *
 * Idempotent / safe to call on a disabled or unconfigured business
 * (early exits cover both).
 *
 * Server-only.
 *
 * Params:
 *   0: OBJECT - business building
 */

if (!isServer) exitWith {};

params [["_business", objNull, [objNull]]];
if (isNull _business) exitWith {};
if (!alive _business) exitWith {};
if (!(_business getVariable ["BO_businessEnabled", true])) exitWith {};

private _type = _business getVariable ["BO_businessType", ""];
if (_type isEqualTo "") exitWith {
    BO_LOG_WARN("business", "businessTick: missing BO_businessType var");
};
if (isNil "BO_businessTypes" || {!(_type in BO_businessTypes)}) exitWith {
    private _msg = format ["businessTick: unknown type '%1' (no spec)", _type];
    BO_LOG_WARN("business", _msg);
};

private _spec = BO_businessTypes get _type;
_spec params [
    ["_inputCls", "", [""]],
    ["_outputCls", "", [""]],
    ["_outputPerHr", 0, [0]],
    ["_employees", 0, [0]]
];

// Wages -- mirrors GUERLoop:67-83. Pull WAGE per-hr cost from the
// price gamelogic (set in initVar.sqf via OT_priceData). Skip the
// whole tick if resistance can't cover wages.
private _wagePerHr = [OT_nation, "WAGE", 0] call OT_fnc_getPrice;
private _totalWages = _employees * _wagePerHr;
private _funds = [] call OT_fnc_resistanceFunds;
if (_funds < _totalWages) exitWith {
    format ["Resistance was unable to pay wages at %1", _type] remoteExec ["OT_fnc_notifyMinor", 0, false];
    private _wmsg = format ["Wages skipped at %1 (need $%2, have $%3)", _type, _totalWages, _funds];
    BO_LOG_INFO("business", _wmsg);
};
[-_totalWages] call OT_fnc_resistanceFunds;

// Ensure the I/O crate exists and rebind if necessary.
private _crate = [_business] call BO_fnc_businessEnsureCrate;
if (isNull _crate) exitWith {
    private _cmsg = format ["businessTick: %1 has no I/O crate -- production lost this hour", _type];
    BO_LOG_WARN("business", _cmsg);
};

private _businessPos = getPosATL _business;
private _producedThisHour = _outputPerHr;

// If this business consumes input, gate output on how much input
// was actually available in nearby cargo containers.
if (_inputCls isNotEqualTo "") then {
    private _needed = _outputPerHr;
    private _taken = 0;
    {
        if (_needed <= 0) exitWith {};
        private _c = _x;
        private _stock = _c call OT_fnc_unitStock;
        {
            _x params ["_cls", "_amt"];
            if (_cls isEqualTo _inputCls) exitWith {
                private _toTake = (_amt min _needed);
                [_c, _cls, _toTake] call CBA_fnc_removeItemCargo;
                _taken = _taken + _toTake;
                _needed = _needed - _toTake;
            };
        } forEach (_stock);
    } forEach (_businessPos nearObjects [OT_item_CargoContainer, 50]);
    _producedThisHour = _taken;
    if (_taken < _outputPerHr) then {
        private _msg = format ["%1 short on %2 -- produced %3/%4 this hour", _type, _inputCls, _taken, _outputPerHr];
        BO_LOG_INFO("business", _msg);
    };
};

if (_producedThisHour > 0 && _outputCls isNotEqualTo "") then {
    _crate addItemCargoGlobal [_outputCls, _producedThisHour];
    [AUDIT_ADMIN, format ["Business produced %1x %2", _producedThisHour, _outputCls], [_type, getPosATL _business], "", ""] call BO_fnc_auditServer;
    private _msg = format ["%1 produced %2x %3 (wages $%4)", _type, _producedThisHour, _outputCls, _totalWages];
    BO_LOG_DEBUG("business", _msg);
};
