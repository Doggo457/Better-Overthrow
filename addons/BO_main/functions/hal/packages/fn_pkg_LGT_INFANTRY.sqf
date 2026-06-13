#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_LGT_INFANTRY
 *
 * Hour-2 fireteam: TeamLeader + 3 riflemen in a light transport,
 * dismounting up the road. Locked #16 derivation:
 *   OT_NATO_Unit_TeamLeader + 3x rifle pool, OT_NATO_Vehicle_Transport_Light
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _classes = [missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""]];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
for "_i" from 1 to 3 do { _classes pushBack (selectRandom _pool) };
_classes = _classes select { _x isNotEqualTo "" };

[_origin, _tgt, _classes,
    missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""],
    "ground", false] call BO_HAL_fnc_spawnGroup
