#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_MED_SQUAD
 *
 * Hour-3 squad: SquadLeader + 6 riflemen with an armed ground-support
 * escort (locked #16: selectRandom OT_NATO_Vehicles_GroundSupport,
 * Transport_Light fallback).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _classes = [missionNamespace getVariable ["OT_NATO_Unit_SquadLeader", ""]];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
for "_i" from 1 to 6 do { _classes pushBack (selectRandom _pool) };

// Counter-doctrine attachments (fn_doctrineTraits): a marksman campaign
// earns a counter-sniper overwatch pair; a vehicle campaign earns an
// extra AT tube in every squad.
(missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]])
    params ["_tSniper", "_tCqb", "", "_tMech"];
if (_tSniper >= 0.6) then {
    _classes pushBack (missionNamespace getVariable ["OT_NATO_Unit_Sniper", ""]);
    _classes pushBack (missionNamespace getVariable ["OT_NATO_Unit_Spotter", ""]);
};
if (_tMech >= 0.5) then {
    _classes pushBack (missionNamespace getVariable ["OT_NATO_Unit_AT", ""]);
};
_classes = _classes select { _x isNotEqualTo "" };

private _gs = missionNamespace getVariable ["OT_NATO_Vehicles_GroundSupport", []];
private _vehCls = if (_gs isNotEqualTo []) then { selectRandom _gs } else {
    missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""]
};

[_origin, _tgt, _classes, _vehCls, "ground", false] call BO_HAL_fnc_spawnGroup
