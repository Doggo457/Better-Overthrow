#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryQueueAdjust  -- legacy compat shim.
 *
 * The multi-factory model replaces this with three explicit target
 * helpers (BO_fnc_factoryQueueAddTarget / RemoveTarget / ClearTarget)
 * that operate on a specific factory object's per-object state.
 *
 * This shim is kept so any code or scenario script that still calls
 * the old ["ADD", _cls, _qty] / ["REMOVE", _idx] / ["CLEAR"] form
 * keeps working. It routes the mutation to the FIRST factory in the
 * server registry (typically the starter site for legacy callers),
 * which preserves single-factory semantics for code that wasn't
 * updated to the multi-factory API.
 *
 * Server-only.
 *
 * Params:
 *   0: STRING - operation ("ADD" | "REMOVE" | "CLEAR")
 *   1: STRING - classname (ADD) or unused
 *   2: SCALAR - qty (ADD) or index (REMOVE)
 */

SERVER_ONLY;

params [
    ["_op", "", [""]],
    ["_cls", "", [""]],
    ["_arg", 0, [0]]
];

private _registry = server getVariable ["BO_buildFactories", []];
if (_registry isEqualTo []) exitWith {
    BO_LOG_WARN("factory", "factoryQueueAdjust legacy call but no factories registered");
};

private _factory = _registry select 0;
if (isNull _factory) exitWith {};

switch (_op) do {
    case "ADD":    { [_factory, _cls, _arg] call BO_fnc_factoryQueueAddTarget };
    case "REMOVE": { [_factory, _arg]       call BO_fnc_factoryQueueRemoveTarget };
    case "CLEAR":  { [_factory]             call BO_fnc_factoryQueueClearTarget };
};
