#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_resetLoadoutToDefault
 *
 * Clear the caller's stored loadout override for a unit class so
 * future recruits use the OT baseline (OT_Recruitables / OT_Loadout_Police).
 *
 * Params:
 *   0: STRING - unit class
 */

params [["_cls", "", [""]]];
if (_cls isEqualTo "") exitWith {};

private _uid = getPlayerUID player;
private _key = format ["BO_loadout_%1_%2", _uid, _cls];
players_NS setVariable [_key, nil, true];
"Loadout reset to default" call OT_fnc_notifyMinor;
