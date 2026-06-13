#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_loadPlayerLoadout
 *
 * Read a stored custom loadout for a given player + unit class.
 * Returns [] when no override exists -- callers fall back to
 * OT_Recruitables / OT_Loadout_Police.
 *
 * Params:
 *   0: STRING - player UID
 *   1: STRING - unit class
 *
 * Returns: ARRAY (loadout) or [] if no override.
 */

params [
    ["_uid", "", [""]],
    ["_cls", "", [""]]
];

if (_uid isEqualTo "" || _cls isEqualTo "") exitWith { [] };

private _key = format ["BO_loadout_%1_%2", _uid, _cls];
players_NS getVariable [_key, []]
