#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_spawnGroup
 *
 * Shared package spawner. Spawns a WEST infantry group at an origin,
 * optionally with a crewed transport/armor/air vehicle, and starts it
 * toward a dismount point on the origin side of the target. Movement
 * is a SINGLE MOVE waypoint (Layer 3 deleted: no triple-redundant
 * command stacks); arrival/dismount transitions live in fn_evaluateOp.
 *
 * Params:
 *   0: ARRAY  origin pos
 *   1: ARRAY  target pos
 *   2: ARRAY  infantry classnames
 *   3: STRING vehicle class ("" = on foot)
 *   4: STRING mode: "ground" | "air" | "none"
 *   5: BOOL   holdFire (recon: never engage)
 *
 * Returns: [GROUP infantry, OBJECT vehicle, GROUP crew] (nulls on fail)
 */

SERVER_ONLY;
params [
    ["_origin", [], [[]]],
    ["_tgt", [], [[]]],
    ["_infClasses", [], [[]]],
    ["_vehClass", "", [""]],
    ["_mode", "ground", [""]],
    ["_holdFire", false, [false]]
];
if (_origin isEqualTo [] || {_tgt isEqualTo []}) exitWith { [grpNull, objNull, grpNull] };

([_origin, _tgt, _vehClass] call BO_HAL_fnc_spawnSafely) params ["_spawnPos", "_canDrive"];
if (_mode isEqualTo "ground" && {_vehClass isNotEqualTo ""} && {!_canDrive}) then {
    // Layer 1: unpathable drive -> insert dismounted near target instead.
    _vehClass = "";
    _mode = "none";
};

// ---- infantry -------------------------------------------------------
// When a vehicle owns _spawnPos the dismounts are moveInCargo'd anyway, so
// spawn them clear of the vehicle footprint -- never under a vehicle that's
// about to drop in from altitude.
private _infBasePos = if (_vehClass isNotEqualTo "" && {_mode isNotEqualTo "none"}) then { _spawnPos getPos [22, random 360] } else { _spawnPos };
private _grp = createGroup [west, true];
{
    private _u = _grp createUnit [_x, _infBasePos, [], 8, "FORM"];
    if (!isNull _u) then {
        _u setSkill (missionNamespace getVariable ["BO_HAL_skillBase", 0.55]);
        _u setVariable ["BO_HAL_unit", true, false];
    };
} forEach _infClasses;

if ((units _grp) isEqualTo []) exitWith {
    deleteGroup _grp;
    [grpNull, objNull, grpNull]
};

if (_holdFire) then {
    _grp setCombatMode "BLUE";
    _grp setBehaviour "AWARE";
    { _x disableAI "AUTOTARGET" } forEach (units _grp);
} else {
    _grp setCombatMode "YELLOW";
    _grp setBehaviour "AWARE";
};
_grp setSpeedMode "FULL";

// ---- vehicle --------------------------------------------------------
private _veh = objNull;
private _crewGrp = grpNull;
if (_vehClass isNotEqualTo "" && {_mode isNotEqualTo "none"}) then {
    if (_mode isEqualTo "air") then {
        _veh = createVehicle [_vehClass, [_spawnPos select 0, _spawnPos select 1, 150], [], 0, "FLY"];
        _veh flyInHeight 120;
    } else {
        _veh = createVehicle [_vehClass, [0, 0, 1000 + random 500], [], 0, "CAN_COLLIDE"];
        _veh setDir (_spawnPos getDir _tgt);
        _veh setPosATL _spawnPos;
    };
    clearWeaponCargoGlobal _veh;
    clearMagazineCargoGlobal _veh;
    _veh allowCrewInImmobile false; // Layer 4: no crews dying in mobility kills
    _veh setVariable ["BO_HAL_unit", true, false];

    createVehicleCrew _veh;

    // Spawn-settle invulnerability: ground vehicles dropped from altitude
    // can jostle on landing -- especially when several spawn near each other
    // -- and the physics solver detonates them. Shield the vehicle + its
    // crew for a few seconds, then restore so the player can still kill it.
    if (_mode isNotEqualTo "air") then {
        private _settle = [_veh] + (crew _veh);
        { _x allowDamage false } forEach _settle;
        [{ { if (!isNull _x) then { _x allowDamage true } } forEach (_this select 0) }, [_settle], 6] call CBA_fnc_waitAndExecute;
    };

    _crewGrp = group (effectiveCommander _veh);
    if (isNull _crewGrp && {!isNull (driver _veh)}) then { _crewGrp = group (driver _veh) };
    if (!isNull _crewGrp) then {
        [_crewGrp, false] call BO_HAL_fnc_dressGroup;
        // CARELESS transit: drivers floor it down the road instead of
        // the AWARE stop-scan-creep crawl. evaluateOp flips the crew
        // to AWARE on contact or arrival.
        _crewGrp setBehaviour (["CARELESS", "AWARE"] select (_mode isEqualTo "air"));
        _crewGrp setSpeedMode "FULL";
    };

    // Mount the infantry.
    { _x moveInCargo _veh } forEach (units _grp);

    // Crew drives/flies to the dismount point on the origin side.
    // Completion radius 40: "close enough" beats a minute of parking
    // ballet at the exact coordinate. Counter-doctrine can stretch the
    // dismount (marksman campaigns: 500m; IED campaigns: 600m) -- the
    // hint is single-use, set by fn_pickHotPackage.
    private _hintD = missionNamespace getVariable ["BO_HAL_hintDismount", 0];
    missionNamespace setVariable ["BO_HAL_hintDismount", 0];
    private _dismount = _tgt getPos [([250 + random 150, _hintD + random 100] select (_hintD > 0)), _tgt getDir _origin];
    if (surfaceIsWater _dismount) then { _dismount = _tgt getPos [300, (_tgt getDir _origin) + 60] };
    private _wp = _crewGrp addWaypoint [_dismount, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointCompletionRadius 40;
} else {
    // On foot: single MOVE to the target area.
    private _wp = _grp addWaypoint [_tgt getPos [80, random 360], 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 25;
};

[_grp, _veh, _crewGrp]
