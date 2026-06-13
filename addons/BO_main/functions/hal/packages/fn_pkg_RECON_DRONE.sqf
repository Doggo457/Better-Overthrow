#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_RECON_DRONE
 *
 * Darter-class ISR: a small UAV loitering over the area, quietly
 * refreshing HAL's sighting buffer while ground responses close in.
 * The buzz overhead IS the tell (no-notifications rule). Cheap (40),
 * WL >= 2. Quiet ingest -- ISR refreshes never spam the provocation
 * queue (that would chain partial ticks off one drone).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp(uav ai), veh(drone), crewGrp(same)]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _clsVar = missionNamespace getVariable ["OT_NATO_Vehicles_ReconDrone", ""];
private _cls = if (_clsVar isEqualType []) then { _clsVar param [0, ""] } else { _clsVar };
if (_cls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

private _uav = createVehicle [_cls, [_origin select 0, _origin select 1, 150], [], 0, "FLY"];
_uav flyInHeight 120;
_uav setVariable ["BO_HAL_unit", true, false];
createVehicleCrew _uav;
private _crew = group ((crew _uav) param [0, objNull]);
if (isNull _crew) exitWith { deleteVehicle _uav; [grpNull, objNull, grpNull] };

[_crew, false] call BO_HAL_fnc_dressGroup;
_crew setBehaviour "CARELESS";
_crew setCombatMode "BLUE";

private _wp = _crew addWaypoint [_tgt, 0];
_wp setWaypointType "LOITER";
_wp setWaypointLoiterType "CIRCLE_L";
_wp setWaypointLoiterRadius 350;
_wp setWaypointCompletionRadius 200;

// ISR loop: every 15s, upsert any visible wanted unit below into
// NATOknownTargets (quiet: no provocation, no partial-tick spam).
[{
    params ["_args", "_pfh"];
    _args params ["_uav", "_tgt"];
    if (isNull _uav || {!alive _uav}) exitWith {
        [_pfh] call CBA_fnc_removePerFrameHandler;
    };
    private _seen = ((_tgt nearEntities [["CAManBase", "LandVehicle"], 500]) select {
        alive _x && { side group _x isEqualTo independent }
        && { !(_x isKindOf "Man") || { !captive _x } }
    }) select 0;
    if (!isNil "_seen" && {!isNull _seen}) then {
        if (([objNull, "VIEW"] checkVisibility [eyePos _uav, eyePos _seen]) > 0.3) then {
            [_seen, getPosATL _seen, "reveal", [], true] call BO_HAL_fnc_ingestSighting;
        };
    };
}, 15, [_uav, +_tgt]] call CBA_fnc_addPerFrameHandler;

[_crew, _uav, _crew]
