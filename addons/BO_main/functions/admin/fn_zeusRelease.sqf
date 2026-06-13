#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zeusRelease
 *
 * Server-side: release whatever curator seat this player holds. Only
 * ever touches the caller's OWN seat (the old shared-curator toggle
 * unassigned whoever happened to hold the module -- General B's
 * toggle-off used to kick General A out of Zeus).
 *
 * Params: 0: OBJECT player
 */

SERVER_ONLY;
params [["_player", objNull, [objNull]]];
if (isNull _player) exitWith {};

{
    private _c = _x select 2;
    if (!isNull _c && {(getAssignedCuratorUnit _c) isEqualTo _player}) then {
        unassignCurator _c;
    };
} forEach (missionNamespace getVariable ["BO_zeusRegistry", []]);

private _msg = format ["Zeus released: %1", name _player];
BO_LOG_INFO("admin", _msg);
