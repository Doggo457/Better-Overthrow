#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_copyLoadoutFromPlayer
 *
 * Copy another player's stored loadout for a given unit class into
 * the caller's own slot. One-shot copy -- the source player can
 * keep editing theirs independently.
 *
 * Params:
 *   0: STRING - source player UID
 *   1: STRING - unit class
 *
 * Returns: BOOL - true if a loadout was copied, false if source had none.
 */

params [
    ["_sourceUID", "", [""]],
    ["_cls", "", [""]]
];

if (_sourceUID isEqualTo "" || _cls isEqualTo "") exitWith { false };

private _src = [_sourceUID, _cls] call BO_fnc_loadPlayerLoadout;
if (_src isEqualTo []) exitWith {
    "That player has no custom loadout for this unit" call OT_fnc_notifyMinor;
    false
};

[_cls, _src] call BO_fnc_savePlayerLoadout;
"Loadout copied" call OT_fnc_notifyMinor;
true
