#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_rebuildGreenforView
 *
 * Player economic assets HAL may strike when the player goes invisible
 * (M6 greenfor branch / V5). FOBs are sanctuary (locked decision #9):
 * anything within 600m of a registered base flag is off the table.
 *
 * Returns: ARRAY of [kind, pos, obj] -- kind in
 *          ["factory", "business", "warehouse"]
 */

SERVER_ONLY;

if (BO_HAL_disableGreenforTargeting) exitWith { [] };

private _bases = server getVariable ["bases", []];
private _sanctuary = {
    params ["_p"];
    (_bases findIf { ((_x select 0) distance2D _p) < 600 }) != -1
};

private _view = [];

{
    if (!isNull _x && {alive _x}) then {
        private _p = getPosATL _x;
        if (!([_p] call _sanctuary)) then { _view pushBack ["factory", _p, _x] };
    };
} forEach (server getVariable ["BO_buildFactories", []]);

{
    if (!isNull _x && {alive _x}) then {
        private _p = getPosATL _x;
        if (!([_p] call _sanctuary)) then { _view pushBack ["business", _p, _x] };
    };
} forEach (server getVariable ["BO_buildBusinesses", []]);

_view
