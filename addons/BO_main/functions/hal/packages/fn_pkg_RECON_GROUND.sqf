#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_RECON_GROUND
 *
 * The design's signature moment: a Hunter parks 800m out, scouts glass
 * the area with binos, and they leave without firing because they were
 * only confirming you exist. holdFire group -- never engages
 * (evaluateOp exfils them immediately if shot at).
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
    "ground", true] call BO_HAL_fnc_spawnGroup) params ["_grp", "_veh", "_crew"];

if (!isNull _grp) then {
    { _x addWeapon "Binocular" } forEach (units _grp select { binocular _x isEqualTo "" });
};

[_grp, _veh, _crew]
