#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_AIR_CAS_DRONE
 *
 * Greyhawk-class armed drone, missile-fit. Three fixes baked in from
 * the first live sessions:
 *
 *   1. MISSILES, NOT BOMBS: prefers the dynamic-loadout airframe and
 *      refits every pylon to the best missile the airframe accepts
 *      (Scalpel/AGM/DAGR class, discovered via
 *      getCompatiblePylonMagazines -- works for modded drones too).
 *   2. IT ACTUALLY FIRES AT PEOPLE: AI won't prosecute infantry with
 *      laser-guided ordnance on its own, so the package runs a
 *      designation loop -- a LaserTargetW tracks the freshest live
 *      sighting under the orbit and the gunner is pointed at it. The
 *      AI then engages the spot regardless of what's standing on it.
 *   3. Never picked against AA-capable kit (ladder logic).
 *
 * Params: 0: origin, 1: target, 2: catalog entry
 * Returns: [grp(uav ai), veh(drone), crewGrp(same)]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _clsVar = missionNamespace getVariable ["OT_NATO_Vehicles_CASDrone", ""];
private _cls = if (_clsVar isEqualType []) then { _clsVar param [0, ""] } else { _clsVar };
if (_cls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

// Vanilla fixed-loadout Greyhawk carries GBUs only; the dynamic-loadout
// airframe accepts missiles. Swap when available.
if (_cls isEqualTo "B_UAV_02_CAS_F" && {isClass (configFile >> "CfgVehicles" >> "B_UAV_02_dynamicLoadout_F")}) then {
    _cls = "B_UAV_02_dynamicLoadout_F";
};

private _uav = createVehicle [_cls, [_origin select 0, _origin select 1, 350], [], 0, "FLY"];
_uav flyInHeight 250;
_uav setVariable ["BO_HAL_unit", true, false];
createVehicleCrew _uav;
private _crew = group ((crew _uav) param [0, objNull]);
if (isNull _crew) exitWith { deleteVehicle _uav; [grpNull, objNull, grpNull] };

// ---- pylon refit: missiles first ------------------------------------
private _pylonCount = count (getAllPylonsInfo _uav);
for "_i" from 1 to _pylonCount do {
    private _mags = _uav getCompatiblePylonMagazines _i;
    private _pick = "";
    {
        private _l = toLower _x;
        if (_pick isEqualTo ""
            && {("scalpel" in _l) || ("agm" in _l) || ("dagr" in _l)}
            && {!("aa" in _l)}) then { _pick = _x };
    } forEach _mags;
    if (_pick isNotEqualTo "") then {
        _uav setPylonLoadout [_i, _pick, true, [0]];
    };
};

[_crew, false] call BO_HAL_fnc_dressGroup;
_crew setBehaviour "COMBAT";
_crew setCombatMode "RED";

private _wp = _crew addWaypoint [_tgt, 0];
_wp setWaypointType "SAD";
_wp setWaypointCompletionRadius 200;

// Hand the drone HAL's current picture so it hunts instead of loiters.
{
    private _obj = _x param [3, objNull];
    if (!isNull _obj && {alive _obj} && {(_obj distance2D _tgt) < 800}) then {
        _crew reveal [_obj, 4];
    };
} forEach (missionNamespace getVariable ["NATOknownTargets", []]);

// ---- designation loop ------------------------------------------------
// Every 12s: pick the freshest live sighting under the orbit, keep a
// west laser spot glued to it, point the gunner. Spot is deleted when
// no target remains or the drone dies (which also ends the PFH).
[{
    params ["_args", "_pfh"];
    _args params ["_uav", "_tgt", "_laser"];
    if (isNull _uav || {!alive _uav}) exitWith {
        if (!isNull _laser) then { deleteVehicle _laser };
        [_pfh] call CBA_fnc_removePerFrameHandler;
    };

    private _best = objNull;
    private _bd = 700;
    {
        private _o = _x param [3, objNull];
        if (!isNull _o && {alive _o}
            && {!(_o isKindOf "Man") || {!captive _o}}) then {
            private _d = _o distance2D _tgt;
            if (_d < _bd) then { _bd = _d; _best = _o };
        };
    } forEach (missionNamespace getVariable ["NATOknownTargets", []]);

    if (isNull _best) then {
        if (!isNull _laser) then { deleteVehicle _laser; _args set [2, objNull] };
    } else {
        private _lp = getPosATL _best;
        _lp set [2, (_lp select 2) + 1];
        if (isNull _laser) then {
            _laser = createVehicle ["LaserTargetW", _lp, [], 0, "CAN_COLLIDE"];
            _args set [2, _laser];
        } else {
            _laser setPosATL _lp;
        };
        private _gnr = gunner _uav;
        if (isNull _gnr) then { _gnr = (crew _uav) param [0, objNull] };
        if (!isNull _gnr) then {
            (group _gnr) reveal [_laser, 4];
            _gnr doTarget _laser;
        };
    };
}, 12, [_uav, +_tgt, objNull]] call CBA_fnc_addPerFrameHandler;

[_crew, _uav, _crew]
