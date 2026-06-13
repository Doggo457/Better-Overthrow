#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_releaseFieldGroup
 *
 * Hand an adopted group back to the world: HAL never deletes units it
 * didn't spawn. Strips the op tag, points them at their anchor, stamps
 * a 3-minute re-adopt cooldown, drops the op record. fieldCommand will
 * pick them up again (and eventually consolidate them into a garrison).
 *
 * Params: 0: ARRAY op record, 1: STRING reason
 */

SERVER_ONLY;
params [["_op", [], [[]]], ["_reason", "released", [""]]];
if (_op isEqualTo []) exitWith {};
_op params ["_opId", "_pkgId", "_grp"];

if (!isNull _grp) then {
    _grp setVariable ["BO_HAL_op", nil, false];
    _grp setVariable ["BO_HAL_releasedAt", serverTime, false];
    _grp setVariable ["BO_HAL_idleSince", serverTime, false];
    private _anchor = _grp getVariable ["BO_HAL_anchor", []];
    if (_anchor isNotEqualTo [] && {({ alive _x } count units _grp) > 0}) then {
        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
        private _wp = _grp addWaypoint [_anchor, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 30;
        _grp setSpeedMode "NORMAL";
        _grp setCombatMode "YELLOW";
    };
};

private _idx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _opId };
if (_idx >= 0) then { BO_HAL_activeOps deleteAt _idx };

["field_release", [_opId, _reason]] call BO_HAL_fnc_aar;
