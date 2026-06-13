#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_recycleOp
 *
 * Remove an op and despawn its assets, optionally refunding budget
 * (retreat cascade formula: survivors/original x cost x 0.7). Never
 * deletes anything a player could be watching: when any player is
 * within OT_spawnDistance of the group, deletion defers to the next
 * evaluate pass (status "fading") -- the units simply hold position
 * until the player leaves. Locked decision D1: kit is NEVER stripped;
 * corpses stay lootable until the regular GC sweeps them.
 *
 * Params: 0: ARRAY op record, 1: BOOL refund (default false),
 *         2: STRING reason
 * Returns: BOOL removed-now
 */

SERVER_ONLY;
params [["_op", [], [[]]], ["_refund", false, [false]], ["_reason", "done", [""]]];
if (_op isEqualTo []) exitWith { false };
_op params ["_opId", "_pkgId", "_grp", "_veh", "_crewGrp", "_tgt", "_origin",
            "_launch", "_status", "_initial", "_reinf", "_cost", "_kind"];

private _living = [];
if (!isNull _grp) then { _living append (units _grp select { alive _x }) };
if (!isNull _crewGrp) then { _living append (units _crewGrp select { alive _x }) };

// Player proximity defers the actual delete (refund intent kept in
// data so the fading retry honors it).
private _watcher = (allPlayers select { alive _x }) findIf {
    private _p = _x;
    (!isNull _grp && {(_p distance2D (leader _grp)) < OT_spawnDistance})
    || {!isNull _veh && {(_p distance2D _veh) < OT_spawnDistance}}
};
if (_watcher != -1) exitWith {
    _op set [8, "fading"];
    _op set [13, serverTime];
    _op set [14, [_refund, _reason]];
    false
};

if (_refund && {_initial > 0}) then {
    private _amount = round (((count _living) / _initial) * _cost * 0.7);
    if (_amount > 0) then {
        server setVariable ["NATOresources", (server getVariable ["NATOresources", 0]) + _amount, true];
        ["refund", [_opId, _amount]] call BO_HAL_fnc_aar;
    };
};

{ deleteVehicle _x } forEach _living;
if (!isNull _veh) then {
    { _veh deleteVehicleCrew _x } forEach (crew _veh);
    deleteVehicle _veh;
};
if (!isNull _grp) then { deleteGroup _grp };
// Air packages track the crew as both grp and crewGrp.
if (!isNull _crewGrp && {_crewGrp isNotEqualTo _grp}) then { deleteGroup _crewGrp };

private _idx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _opId };
if (_idx >= 0) then { BO_HAL_activeOps deleteAt _idx };

// Global single-concurrent-FOB-action latch (locked decision #9).
if (_kind isEqualTo "fob") then { BO_HAL_fobActionActive = false };

// Defeat memory (locked #28): a combat op that ended badly stamps a
// setback for its target area. The hot branch suppresses re-dispatch
// there and the package picker skips the failed weight class -- no
// more same-spot infantry spam.
if (_kind in ["hot", "field", "interdiction"]
    && {_reason in ["wiped", "stranded", "retreat_complete", "transit_timeout", "no_destination"]}) then {
    BO_HAL_setbacks pushBack [+_tgt, serverTime, _pkgId];
    if (count BO_HAL_setbacks > 20) then { BO_HAL_setbacks deleteAt 0 };
};

["recycle", [_opId, _pkgId, _reason, count _living]] call BO_HAL_fnc_aar;
true
