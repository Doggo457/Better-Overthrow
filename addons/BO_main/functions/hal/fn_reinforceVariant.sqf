#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_reinforceVariant
 *
 * V2 reinforce: a half-size echo of the parent package, spawned at the
 * parent's origin, that joins the parent group when it reaches the
 * fight. Costs 80 from the ledger (flat -- the win-prob gate already
 * decided it's worth it).
 *
 * Params: 0: ARRAY parent op record
 * Returns: BOOL launched
 */

SERVER_ONLY;
params [["_op", [], [[]]]];
if (_op isEqualTo []) exitWith { false };
_op params ["_opId", "_pkgId", "_grp", "_veh", "_crewGrp", "_tgt", "_origin"];
if (isNull _grp) exitWith { false };

private _res = server getVariable ["NATOresources", 0];
if (_res < 80) exitWith { false };
server setVariable ["NATOresources", (_res - 80) max 0, true];

private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
if (_pool isEqualTo []) exitWith { false };

private _lead = missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""];
private _classes = [];
if (_lead isNotEqualTo "") then { _classes pushBack _lead };
for "_i" from 1 to 3 do { _classes pushBack (selectRandom _pool) };

private _vehCls = missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""];
([_origin, _tgt, _classes, _vehCls, "ground", false] call BO_HAL_fnc_spawnGroup)
    params ["_rGrp", "_rVeh", "_rCrew"];
if (isNull _rGrp) exitWith {
    server setVariable ["NATOresources", (server getVariable ["NATOresources", 0]) + 80, true];
    false
};

[_rGrp, false] call BO_HAL_fnc_dressGroup;
_rGrp setVariable ["BO_HAL_op", _opId, false];
if (!isNull _rCrew) then { _rCrew setVariable ["BO_HAL_op", -1, false] };

// Child op: joins parent on arrival (evaluateOp folds it in).
private _childId = (server getVariable ["BO_HAL_opCounter", 0]) + 1;
server setVariable ["BO_HAL_opCounter", _childId];
BO_HAL_activeOps pushBack [
    _childId, _pkgId, _rGrp, _rVeh, _rCrew, +_tgt, +_origin,
    serverTime, "transit", count units _rGrp, 0, 80, "reinforce", serverTime, [_opId]
];

["reinforce", [_opId, _childId]] call BO_HAL_fnc_aar;
true
