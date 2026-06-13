#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_AIR_LIGHT
 *
 * Armed-heli response to an air player. WL >= 6 (addendum AA gate).
 * Crew-only package: the helo SADs the target area, watchdog re-asserts
 * flyInHeight against LAMBS.
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp(crew), veh(helo), crewGrp(same)]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _smalls = missionNamespace getVariable ["OT_NATO_Vehicles_AirSupport_Small", []];
private _cls = if (_smalls isNotEqualTo []) then { selectRandom _smalls } else {
    private _big = missionNamespace getVariable ["OT_NATO_Vehicles_AirSupport", []];
    if (_big isNotEqualTo []) then { selectRandom _big } else { "" }
};
if (_cls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

private _heli = createVehicle [_cls, [_origin select 0, _origin select 1, 200], [], 0, "FLY"];
_heli flyInHeight 150;
_heli setVariable ["BO_HAL_unit", true, false];
createVehicleCrew _heli;
private _crew = group (effectiveCommander _heli);
if (isNull _crew && {!isNull driver _heli}) then { _crew = group (driver _heli) };
if (isNull _crew) exitWith { deleteVehicle _heli; [grpNull, objNull, grpNull] };

[_crew, false] call BO_HAL_fnc_dressGroup;
_crew setBehaviour "COMBAT";
_crew setCombatMode "RED";

private _wp = _crew addWaypoint [_tgt, 0];
_wp setWaypointType "SAD";

// Crew doubles as the op's tracked infantry group.
[_crew, _heli, _crew]
