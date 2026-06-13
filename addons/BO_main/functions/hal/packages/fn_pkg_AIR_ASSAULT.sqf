#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_AIR_ASSAULT
 *
 * Heliborne squad (WL >= 5): SL + 6 riflemen in a transport helo that
 * lands them short of the target and returns to base. The landing /
 * dismount / RTB choreography lives in fn_evaluateOp's air-arrival
 * branch; the helo waits at its origin base and despawns with the op.
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp, veh(helo), crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _classes = [missionNamespace getVariable ["OT_NATO_Unit_SquadLeader", ""]];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
for "_i" from 1 to 6 do { _classes pushBack (selectRandom _pool) };
_classes = _classes select { _x isNotEqualTo "" };

private _heliCls = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport_Small", ""];
if (_heliCls isEqualTo "") then {
    private _arr = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport", []];
    if (_arr isEqualType "") then { _heliCls = _arr } else { _heliCls = _arr param [0, ""] };
};
if (_heliCls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

([_origin, _tgt, _classes, _heliCls, "air", false] call BO_HAL_fnc_spawnGroup)
    params ["_grp", "_heli", "_crew"];

[_grp, _heli, _crew]
