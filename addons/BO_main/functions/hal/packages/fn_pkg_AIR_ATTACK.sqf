#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_AIR_ATTACK
 *
 * Heavy attack helicopter (WL >= 6): Blackfoot-class gunship from
 * OT_NATO_Vehicles_AirSupport SADs the target area with HAL's live
 * picture pre-revealed. The premium air rung above AIR_LIGHT's armed
 * scout. Never picked against AA-capable kit (ladder logic).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp(crew), veh(heli), crewGrp(same)]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _pool = missionNamespace getVariable ["OT_NATO_Vehicles_AirSupport", []];
private _cls = if (_pool isEqualType "") then { _pool } else {
    if (_pool isNotEqualTo []) then { selectRandom _pool } else { "" }
};
if (_cls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

private _heli = createVehicle [_cls, [_origin select 0, _origin select 1, 250], [], 0, "FLY"];
_heli flyInHeight 180;
_heli setVariable ["BO_HAL_unit", true, false];
createVehicleCrew _heli;
private _crew = group ((crew _heli) param [0, objNull]);
if (isNull _crew) exitWith { deleteVehicle _heli; [grpNull, objNull, grpNull] };

[_crew, false] call BO_HAL_fnc_dressGroup;
_crew setBehaviour "COMBAT";
_crew setCombatMode "RED";

private _wp = _crew addWaypoint [_tgt, 0];
_wp setWaypointType "SAD";
_wp setWaypointCompletionRadius 250;

{
    private _obj = _x param [3, objNull];
    if (!isNull _obj && {alive _obj} && {(_obj distance2D _tgt) < 900}) then {
        _crew reveal [_obj, 4];
    };
} forEach (missionNamespace getVariable ["NATOknownTargets", []]);

[_crew, _heli, _crew]
