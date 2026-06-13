#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_removeRecruitsByUnits
 *
 * Server-authoritative removal from the `recruits` array on the OT
 * `server` namespace. Companion to BO_fnc_addRecruit; needed when
 * a recruit graduates into a custom squad (see fn_createSquad).
 * Atomic single read-modify-write, broadcasts on completion.
 *
 * Removes any recruit entry whose unit (index 2) is in the passed
 * unit list. Silent no-op when the array is empty or no matches.
 *
 * Intended call site:
 *   [_units] remoteExec ["BO_fnc_removeRecruitsByUnits", 2, false];
 *
 * Params:
 *   0: ARRAY of OBJECT - units whose recruit entries should be pruned
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [["_units", [], [[]]]];

if (_units isEqualTo []) exitWith {};

private _recruits = server getVariable ["recruits", []];
if (_recruits isEqualTo []) exitWith {};

private _remove = [];
{
    if ((_x select 2) in _units) then {
        _remove pushBack _x;
    };
} forEach _recruits;

if (_remove isEqualTo []) exitWith {};

{
    _recruits deleteAt (_recruits find _x);
} forEach _remove;

server setVariable ["recruits", _recruits, true];
