#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_RECON_AIR
 *
 * Overflight: an unarmed-ish transport helo at altitude, two lazy
 * passes over the area, then home. You hear an engine at altitude --
 * that's the whole message (no-notifications rule).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp(crew), veh(helo), crewGrp(same)]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _cls = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport_Small", ""];
if (_cls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

private _heli = createVehicle [_cls, [_origin select 0, _origin select 1, 250], [], 0, "FLY"];
_heli flyInHeight 200;
_heli setVariable ["BO_HAL_unit", true, false];
createVehicleCrew _heli;
private _crew = group (effectiveCommander _heli);
if (isNull _crew && {!isNull driver _heli}) then { _crew = group (driver _heli) };
if (isNull _crew) exitWith { deleteVehicle _heli; [grpNull, objNull, grpNull] };

[_crew, false] call BO_HAL_fnc_dressGroup;
_crew setBehaviour "CARELESS";
_crew setCombatMode "BLUE";

// Two offset passes over the target.
private _wp1 = _crew addWaypoint [_tgt getPos [300, random 360], 0];
_wp1 setWaypointType "MOVE";
private _wp2 = _crew addWaypoint [_tgt getPos [400, random 360], 0];
_wp2 setWaypointType "MOVE";

[_crew, _heli, _crew]
