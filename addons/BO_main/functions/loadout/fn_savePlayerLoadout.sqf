#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_savePlayerLoadout
 *
 * Persist a custom recruit loadout for the calling player + a given
 * unit class. Replaces the vanilla OT pattern of overwriting the
 * shared OT_Recruitables array (which produced the well-known bug
 * where two players editing the same unit class clobber each other).
 *
 * Storage: players_NS getVariable ["BO_loadout_<UID>_<class>", ...].
 * That key is captured by OT's save loop (allVariables players_NS),
 * so persistence is free.
 *
 * Params:
 *   0: STRING - unit class
 *   1: ARRAY  - loadout (getUnitLoadout shape)
 */

params [
    ["_cls", "", [""]],
    ["_loadout", [], [[]]]
];

if (_cls isEqualTo "" || _loadout isEqualTo []) exitWith {};

private _uid = getPlayerUID player;
private _key = format ["BO_loadout_%1_%2", _uid, _cls];
players_NS setVariable [_key, _loadout, true];
