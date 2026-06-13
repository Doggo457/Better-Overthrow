#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_LGT_INFANTRY_RURAL
 *
 * v2 rural response: sniper/spotter pair plus two riflemen for
 * treeline players -- quieter, nastier than a fireteam in the open.
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _classes = [
    missionNamespace getVariable ["OT_NATO_Unit_Sniper", ""],
    missionNamespace getVariable ["OT_NATO_Unit_Spotter", ""]
];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
if (_pool isNotEqualTo []) then {
    _classes pushBack (selectRandom _pool);
    _classes pushBack (selectRandom _pool);
};
_classes = _classes select { _x isNotEqualTo "" };

([_origin, _tgt, _classes,
    missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""],
    "ground", false] call BO_HAL_fnc_spawnGroup) params ["_grp", "_veh", "_crew"];

if (!isNull _grp) then {
    _grp setBehaviour "STEALTH";
    _grp setSpeedMode "LIMITED";
};

[_grp, _veh, _crew]
