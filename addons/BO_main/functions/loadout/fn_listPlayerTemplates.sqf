#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_listPlayerTemplates
 *
 * Return the unit classes the calling player (or a specific UID) has
 * a custom loadout stored for. Used by the loadout-templates dialog
 * to show what's editable per player.
 *
 * Params:
 *   0: STRING - player UID (defaults to current player)
 *
 * Returns: ARRAY of unit class strings.
 */

params [["_uid", getPlayerUID player, [""]]];

private _prefix = format ["BO_loadout_%1_", _uid];
private _prefixLen = count _prefix;

(allVariables players_NS) select {
    (_x select [0, _prefixLen]) isEqualTo _prefix
} apply {
    _x select [_prefixLen]
}
