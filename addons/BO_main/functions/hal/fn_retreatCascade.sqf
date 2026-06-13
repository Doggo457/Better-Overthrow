#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_retreatCascade
 *
 * Locked decisions #13/#14: when a package crosses the retreat
 * threshold, survivors are extracted via a 3-tier cascade.
 *
 *   1. Transport sized to survivor count, spawned AT the destination,
 *      drives/flies to the survivors. Transport is free; killing it
 *      before pickup strands the survivors (despawn, NO refund).
 *   2. Pickup: moveInCargo when adjacent; 90s timeout leaves
 *      stragglers behind (despawned, they don't count for refund).
 *   3. Destination: nearest NATO objective/airport/HQ not abandoned ->
 *      nearest NATO-held town -> last gasp: commit survivors to a
 *      counter-attack on the lowest-stability resistance town
 *      (NO refund -- NATO's last lunge).
 *
 * Refund on final despawn: alive/original x cost x 0.7 (wear-and-tear
 * tax), handled by fn_recycleOp; arrival behavior in fn_evaluateOp via
 * statuses "extracting" -> "garrisoned"/"committed".
 *
 * Params: 0: ARRAY op record (mutated in place)
 */

SERVER_ONLY;
params [["_op", [], [[]]]];
if (_op isEqualTo []) exitWith {};
_op params ["_opId", "_pkgId", "_grp", "_veh", "_crewGrp", "_tgt"];

if (isNull _grp) exitWith {};
private _survivors = (units _grp) select { alive _x && { vehicle _x isEqualTo _x } };
private _n = count _survivors;
if (_n isEqualTo 0) exitWith {
    [_op, false, "wiped"] call BO_HAL_fnc_recycleOp;
};

// Old package vehicle is abandoned where it stands (combat loss).
// Crew keeps fighting as part of the group if dismounted earlier.

// ---- step 3 first: resolve the destination --------------------------
private _abandoned = server getVariable ["NATOabandoned", []];
private _dest = [];
private _destKind = "";

private _objectives = (missionNamespace getVariable ["OT_objectiveData", []])
    + (missionNamespace getVariable ["OT_airportData", []]);
private _best = 1e9;
{
    _x params ["_obpos", "_name"];
    if (!(_name in _abandoned)) then {
        private _d = _obpos distance2D (leader _grp);
        if (_d < _best) then { _best = _d; _dest = +_obpos; _destKind = "base" };
    };
} forEach _objectives;

if (_dest isEqualTo []) then {
    // NATO-held towns: OT_allTowns not in NATOabandoned.
    private _bestT = 1e9;
    {
        if (!(_x in _abandoned)) then {
            private _tp = server getVariable [_x, []];
            if (_tp isNotEqualTo []) then {
                private _d = _tp distance2D (leader _grp);
                if (_d < _bestT) then { _bestT = _d; _dest = +_tp; _destKind = "town" };
            };
        };
    } forEach (missionNamespace getVariable ["OT_allTowns", []]);
};

if (_dest isEqualTo []) then {
    // Last gasp: zero NATO bases AND zero NATO towns. Commit the
    // survivors against the lowest-stability resistance town.
    private _worst = ["", 101];
    {
        private _stab = server getVariable [format ["stability%1", _x], 100];
        if (_stab < (_worst select 1)) then { _worst = [_x, _stab] };
    } forEach (missionNamespace getVariable ["OT_allTowns", []]);
    private _tname = _worst select 0;
    if (_tname isNotEqualTo "") then {
        _dest = server getVariable [_tname, [0,0,0]];
        _destKind = "lastgasp";
        [_tname, 200] spawn OT_fnc_NATOCounterTown;
    };
};

if (_dest isEqualTo []) exitWith {
    [_op, false, "no_destination"] call BO_HAL_fnc_recycleOp;
};

// ---- step 1: transport sized to survivor count (locked #14) --------
// AA threat seen recently anywhere => no air extraction.
private _aaSeen = ((missionNamespace getVariable ["NATOknownTargets", []]) findIf {
    private _k = _x param [6, []];
    _k isEqualType [] && { count _k > 3 } && { (_k select 3) isEqualTo "AA-capable" }
}) != -1;

private _transportCls = "";
switch (true) do {
    case (_n <= 4):  { _transportCls = missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""] };
    case (_n <= 6):  {
        private _gs = missionNamespace getVariable ["OT_NATO_Vehicles_GroundSupport", []];
        if (_gs isNotEqualTo []) then { _transportCls = selectRandom _gs };
    };
    case (_n <= 12): {
        private _tr = missionNamespace getVariable ["OT_NATO_Vehicle_Transport", []];
        if (_tr isEqualType "") then { _transportCls = _tr } else {
            if (_tr isNotEqualTo []) then { _transportCls = selectRandom _tr };
        };
    };
    default {
        if (!_aaSeen) then {
            _transportCls = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport_Large", ""];
        };
    };
};
if (_transportCls isEqualTo "") then {
    private _tr = missionNamespace getVariable ["OT_NATO_Vehicle_Transport", []];
    _transportCls = if (_tr isEqualType "") then { _tr } else { _tr param [0, ""] };
};
if (_transportCls isEqualTo "") exitWith {
    // Faction has no transport at all: survivors leg it home.
    [_grp, _tgt] call BO_HAL_fnc_breakContact;
    private _wp = _grp addWaypoint [_dest, 1];
    _wp setWaypointType "MOVE";
    _op set [8, "extracting"];
    _op set [13, serverTime];
    _op set [14, [_dest, _destKind, objNull, grpNull]];
};

private _isAir = _transportCls isKindOf ["Air", configFile >> "CfgVehicles"];

// Survivors break contact toward a rally point while the ride comes in.
private _rally = [_grp, _tgt] call BO_HAL_fnc_breakContact;

private _trans = objNull;
private _transCrew = grpNull;
if (_isAir) then {
    _trans = createVehicle [_transportCls, [_dest select 0, _dest select 1, 150], [], 0, "FLY"];
    _trans flyInHeight 100;
} else {
    private _sp = _dest findEmptyPosition [5, 150, _transportCls];
    if (_sp isEqualTo []) then { _sp = +_dest };
    _trans = createVehicle [_transportCls, [0, 0, 1200 + random 400], [], 0, "CAN_COLLIDE"];
    _trans setDir (_dest getDir _rally);
    _trans setPosATL _sp;
};
clearWeaponCargoGlobal _trans;
clearMagazineCargoGlobal _trans;
_trans allowCrewInImmobile false;
_trans setVariable ["BO_HAL_unit", true, false];
createVehicleCrew _trans;
_transCrew = group (effectiveCommander _trans);
if (isNull _transCrew && {!isNull driver _trans}) then { _transCrew = group (driver _trans) };
if (!isNull _transCrew) then {
    [_transCrew, false] call BO_HAL_fnc_dressGroup;
    _transCrew setVariable ["BO_HAL_op", -1, false]; // hands-off for fieldCommand
    _transCrew setBehaviour "CARELESS";
    _transCrew setCombatMode "BLUE";
    _transCrew setSpeedMode "FULL";
    private _wp = _transCrew addWaypoint [_rally, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointCompletionRadius 40;
};

_op set [8, "retreating"];
_op set [13, serverTime];
// data: [dest, destKind, transport, transportCrew, rally, pickupDeadline]
_op set [14, [_dest, _destKind, _trans, _transCrew, _rally, -1]];

["retreat_begin", [_opId, _pkgId, _n, _destKind]] call BO_HAL_fnc_aar;
