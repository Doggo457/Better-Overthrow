#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_decayTargets
 *
 * M3 decay pass over NATOknownTargets: halve priority on entries older
 * than 450 game-seconds, drop dead/null objects and entries older than
 * 900. (OT's own sweeper culls at 800; the 900 ceiling is a belt-and-
 * braces second line, the halving is the part OT doesn't do.)
 */

SERVER_ONLY;
if (isNil "NATOknownTargets") exitWith {};

private _now = time;
NATOknownTargets = NATOknownTargets select {
    private _obj = _x param [3, objNull];
    private _age = _now - (_x param [5, _now]);
    if (_age > 450 && {count _x > 2}) then {
        _x set [2, ((_x select 2) / 2) max 0];
    };
    !isNull _obj && {alive _obj} && {_age < 900}
};
