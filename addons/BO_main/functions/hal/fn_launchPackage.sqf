#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_launchPackage
 *
 * Debit NATOresources, pick a launch origin, run the package builder,
 * dress the result and register the op.
 *
 * Op record (BO_HAL_activeOps entry):
 *   0 opId  1 pkgId  2 grp  3 veh  4 crewGrp  5 tgtPos  6 originPos
 *   7 launchTime(serverTime)  8 status  9 initialCount  10 reinfCount
 *   11 cost  12 kind  13 stateStamp  14 data
 *
 * Params:
 *   0: ARRAY catalog entry
 *   1: ARRAY target pos
 *   2: STRING kind: "hot"|"recon"|"greenfor"|"fob"|"hunter"|"reinforce"
 * Returns: NUMBER opId, or -1 on failure (budget refunded).
 */

SERVER_ONLY;
params [["_pkg", [], [[]]], ["_tgt", [], [[]]], ["_kind", "hot", [""]]];
if (_pkg isEqualTo [] || {_tgt isEqualTo []}) exitWith { -1 };
_pkg params ["_pkgId", "_cost", "_wlMin", "_required", "_builder"];

if (count BO_HAL_activeOps >= BO_HAL_maxConcurrentOps) exitWith { -1 };

// Drone discipline: ONE Darter aloft at a time (live sessions had ~5
// stacked from adjunct + cold-branch + surge ISR all rolling).
if (_pkgId isEqualTo "RECON_DRONE"
    && {(BO_HAL_activeOps findIf { (_x select 1) isEqualTo "RECON_DRONE" }) != -1}) exitWith { -1 };

// Debit first (locked decision #3: single ledger, NATOresources direct).
private _res = server getVariable ["NATOresources", 0];
if (_res < _cost) exitWith { -1 };
server setVariable ["NATOresources", (_res - _cost) max 0, true];

private _wantAir = _pkgId in ["AIR_LIGHT", "RECON_AIR", "CTRG_HUNTER"];
private _origin = [_tgt, _wantAir] call BO_HAL_fnc_pickLaunchOrigin;
if (_origin isEqualTo []) exitWith {
    server setVariable ["NATOresources", (server getVariable ["NATOresources", 0]) + _cost, true];
    ["launch_abort_no_origin", [_pkgId]] call BO_HAL_fnc_aar;
    -1
};

private _result = [_origin, _tgt, _pkg] call (missionNamespace getVariable [_builder, { [grpNull, objNull, grpNull] }]);
_result params [["_grp", grpNull, [grpNull]], ["_veh", objNull, [objNull]], ["_crewGrp", grpNull, [grpNull]]];

// Delegated packages (GREENFOR_HIT hands the strike to OT's own
// counter-attack machinery): cost spent, nothing to track.
if (isNull _grp && {isNull _veh}) exitWith {
    if (_pkgId isEqualTo "GREENFOR_HIT") then {
        ["launch_delegated", [_pkgId, _tgt]] call BO_HAL_fnc_aar;
        0
    } else {
        server setVariable ["NATOresources", (server getVariable ["NATOresources", 0]) + _cost, true];
        ["launch_abort_builder", [_pkgId]] call BO_HAL_fnc_aar;
        -1
    }
};

[_grp, _kind isEqualTo "hot"] call BO_HAL_fnc_dressGroup;

private _opId = (server getVariable ["BO_HAL_opCounter", 0]) + 1;
server setVariable ["BO_HAL_opCounter", _opId];

private _initial = count (units _grp);
if (!isNull _crewGrp) then { _initial = _initial + count (units _crewGrp) };

_grp setVariable ["BO_HAL_op", _opId, false];
_grp setVariable ["initialStrength", (count units _grp) max 1, false];
// Crew group carries the op tag too, so the field-command pass never
// adopts a package's ride as a stray patrol.
if (!isNull _crewGrp) then { _crewGrp setVariable ["BO_HAL_op", _opId, false] };

BO_HAL_activeOps pushBack [
    _opId, _pkgId, _grp, _veh, _crewGrp, +_tgt, +_origin,
    serverTime, "transit", _initial, 0, _cost, _kind, serverTime, []
];

["launch", [_opId, _pkgId, _kind, round (_origin distance2D _tgt)]] call BO_HAL_fnc_aar;
private _lmsg = format ["HAL launch op=%1 pkg=%2 kind=%3 cost=%4 dist=%5m",
    _opId, _pkgId, _kind, _cost, round (_origin distance2D _tgt)];
BO_LOG_INFO("hal", _lmsg);

_opId
