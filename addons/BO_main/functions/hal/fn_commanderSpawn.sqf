#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_commanderSpawn
 *
 * Build the commander's physical presence at his base (called by the
 * presence PFH when players approach):
 *
 *   - the COMMANDER (OT_NATO_Unit_HVT) inside a random building
 *     position of a random structure at the base, held in place
 *   - 2x bodyguard fireteams (TL + 3 rifles each) patrolling the
 *     compound, elite skill
 *   - 2x armed vehicles (GroundSupport / TankSupport at WL>=6) on
 *     short overwatch loops
 *   - 1x attack helicopter in a CONSTANT orbit over the base
 *
 * Everything derives from OT_NATO_* (multi-nation), is tagged
 * BO_HAL_unit + BO_HAL_cmdDetail, and is excluded from field-command
 * adoption via the BO_HAL_op = -1 sentinel.
 */

SERVER_ONLY;

if (BO_HAL_cmdSpawned) exitWith {};
private _pos = missionNamespace getVariable ["BO_HAL_cmdPos", []];
if (_pos isEqualTo []) exitWith {};
BO_HAL_cmdSpawned = true;
BO_HAL_cmdObjects = [];

private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
private _mark = {
    params ["_o"];
    _o setVariable ["BO_HAL_unit", true, false];
    _o setVariable ["BO_HAL_cmdDetail", true, false];
    BO_HAL_cmdObjects pushBack _o;
};

// ---- the man himself, inside a random building ----------------------
private _hvtCls = missionNamespace getVariable ["OT_NATO_Unit_HVT", ""];
if (_hvtCls isEqualTo "" && {_pool isNotEqualTo []}) then { _hvtCls = selectRandom _pool };
private _buildings = (nearestObjects [_pos, ["House", "Building"], 175]) select {
    count (_x buildingPos -1) > 0
};
private _cmdPosExact = _pos;
if (_buildings isNotEqualTo []) then {
    private _b = selectRandom _buildings;
    private _bps = (_b buildingPos -1) select { !(_x isEqualTo [0,0,0]) };
    if (_bps isNotEqualTo []) then { _cmdPosExact = selectRandom _bps };
};

private _cmdGrp = createGroup [west, true];
private _cmd = _cmdGrp createUnit [_hvtCls, _cmdPosExact, [], 0, "CAN_COLLIDE"];
_cmd setPosATL _cmdPosExact;
_cmd setSkill 0.9;
_cmd disableAI "PATH";          // he stays in his office
_cmd setUnitPos "UP";
_cmd setVariable ["BO_HAL_commander", true, true];
[_cmd] call _mark;
_cmdGrp setVariable ["BO_HAL_op", -1, false];
[_cmdGrp, false] call BO_HAL_fnc_dressGroup;

// MPKilled fires wherever he dies; the server-side body does the rest.
_cmd addMPEventHandler ["MPKilled", {
    params ["_unit"];
    if (!isServer) exitWith {};
    [_unit] call BO_HAL_fnc_commanderKilled;
}];

// ---- bodyguard fireteams --------------------------------------------
private _tl = missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""];
for "_t" from 1 to 2 do {
    private _g = createGroup [west, true];
    private _classes = [_tl];
    for "_i" from 1 to 3 do { _classes pushBack (selectRandom _pool) };
    {
        if (_x isNotEqualTo "") then {
            private _u = _g createUnit [_x, _pos getPos [10 + random 30, random 360], [], 4, "FORM"];
            _u setSkill 0.8;
            [_u] call _mark;
        };
    } forEach _classes;
    _g setVariable ["BO_HAL_op", -1, false];
    [_g, false] call BO_HAL_fnc_dressGroup;
    _g setBehaviour "SAFE";
    private _wp = _g addWaypoint [_pos getPos [40, random 360], 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 20;
    private _wp2 = _g addWaypoint [_pos getPos [40, random 360], 0];
    _wp2 setWaypointType "CYCLE";
};

// ---- armed vehicles ---------------------------------------------------
private _wl = round (server getVariable ["BO_warLevel", 1]);
private _vehPools = [missionNamespace getVariable ["OT_NATO_Vehicles_GroundSupport", []]];
if (_wl >= 6) then { _vehPools pushBack (missionNamespace getVariable ["OT_NATO_Vehicles_TankSupport", []]) };
{
    private _pl = _x;
    if (_pl isNotEqualTo []) then {
        private _cls = selectRandom _pl;
        private _sp = _pos findEmptyPosition [15, 120, _cls];
        if (_sp isEqualTo []) then { _sp = _pos getPos [35, random 360] };
        private _v = createVehicle [_cls, [0, 0, 800 + random 200], [], 0, "CAN_COLLIDE"];
        _v setDir (random 360);
        _v setPosATL _sp;
        _v allowCrewInImmobile false;
        createVehicleCrew _v;
        [_v] call _mark;
        { [_x] call _mark } forEach (crew _v);
        private _cg = group ((crew _v) param [0, objNull]);
        if (!isNull _cg) then {
            _cg setVariable ["BO_HAL_op", -1, false];
            [_cg, false] call BO_HAL_fnc_dressGroup;
            private _wpv = _cg addWaypoint [_pos getPos [90, random 360], 0];
            _wpv setWaypointType "MOVE";
            _wpv setWaypointCompletionRadius 40;
            private _wpc = _cg addWaypoint [_pos getPos [90, random 360], 0];
            _wpc setWaypointType "CYCLE";
        };
    };
} forEach _vehPools;

// ---- constant attack-helicopter orbit --------------------------------
private _heliPool = missionNamespace getVariable ["OT_NATO_Vehicles_AirSupport", []];
if (_heliPool isEqualTo []) then {
    _heliPool = missionNamespace getVariable ["OT_NATO_Vehicles_AirSupport_Small", []];
};
if (_heliPool isNotEqualTo []) then {
    private _hCls = selectRandom _heliPool;
    private _h = createVehicle [_hCls, [_pos select 0, _pos select 1, 200], [], 0, "FLY"];
    _h flyInHeight 150;
    createVehicleCrew _h;
    [_h] call _mark;
    { [_x] call _mark } forEach (crew _h);
    private _hg = group ((crew _h) param [0, objNull]);
    if (!isNull _hg) then {
        _hg setVariable ["BO_HAL_op", -1, false];
        [_hg, false] call BO_HAL_fnc_dressGroup;
        _hg setBehaviour "AWARE";
        _hg setCombatMode "RED";
        private _wph = _hg addWaypoint [_pos, 0];
        _wph setWaypointType "LOITER";
        _wph setWaypointLoiterType "CIRCLE_L";
        _wph setWaypointLoiterRadius 400;
    };
};

["commander_spawned", [server getVariable ["BO_HAL_cmdBase", "?"], count BO_HAL_cmdObjects]] call BO_HAL_fnc_aar;
