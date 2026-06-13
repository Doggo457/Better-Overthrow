#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_fobTouch
 *
 * Register/refresh a player FOB in HAL's registry. Hooked into
 * BO_fnc_registerBase and replayed over `bases` at init.
 *
 * Registry entry: [posKey(pos array), name, pos, lastProbeServerTime]
 *
 * Params: 0: ARRAY base entry ([pos, name, ownerUID])
 */

SERVER_ONLY;
params [["_baseEntry", [], [[]]]];
if (_baseEntry isEqualTo []) exitWith {};

// `bases` slot 0 is historically a flag OBJECT or a position array
// (see fn_registerBase header). Normalize to a position.
private _key = _baseEntry param [0, []];
private _pos = switch (true) do {
    case (_key isEqualType objNull): { if (isNull _key) then { [] } else { getPosATL _key } };
    case (_key isEqualType [] && {count _key >= 2}): { +_key };
    default { [] };
};
private _name = _baseEntry param [1, ""];
if (!(_name isEqualType "")) then { _name = "" };
if (_pos isEqualTo []) exitWith {};

private _reg = server getVariable ["BO_HAL_fobRegistry", []];
private _idx = _reg findIf { ((_x select 0) distance2D _pos) < 50 };
if (_idx >= 0) then {
    (_reg select _idx) set [1, _name];
} else {
    // [posKey, name, pos, lastProbe, lastPlayerNear]
    _reg pushBack [+_pos, _name, +_pos, 0, 0];
};
server setVariable ["BO_HAL_fobRegistry", _reg];
