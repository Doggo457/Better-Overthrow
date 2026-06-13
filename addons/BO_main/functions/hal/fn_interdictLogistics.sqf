#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_interdictLogistics
 *
 * "Cut supply lines" (PLAN Phase 3 strategic objective). When a player
 * logistics delivery is in transit and the greenfor branch fires, HAL
 * may put an ambush team on the route:
 *
 *   - WL >= 4 (an organized interdiction campaign, not banditry)
 *   - delivery must have >= 240s remaining (worth intercepting)
 *   - one interdiction per delivery
 *   - the delivery's ETA is extended +60% of base travel once -- the
 *     route's status line (logistics dialog) reads "ambushed", which
 *     is the player's cue and counterplay window
 *   - if the ambush is still standing at the extended ETA, the
 *     delivery FAILS and the cargo returns to the source warehouse
 *     (resolution lives in fn_evaluateOp, kind "interdiction")
 *   - clear the ambush (or just outlast it -- it recycles like any op)
 *     and the delivery completes on the extended clock
 *
 * Returns: BOOL launched
 */

SERVER_ONLY;

if (BO_HAL_disableGreenforTargeting) exitWith { false };

private _wl = round (server getVariable ["BO_warLevel", 1]);
if (_wl < 4) exitWith { false };

private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];
if (_deliveries isEqualTo []) exitWith { false };

private _now = serverTime;
private _pick = [];
{
    _x params ["_dId", "_routeId", "_start", "_eta"];
    if (_pick isEqualTo []
        && {(_eta - _now) >= 240}
        && {(BO_HAL_activeOps findIf {
            (_x select 12) isEqualTo "interdiction"
            && {((_x select 14) param [0, ""]) isEqualTo _dId}
        }) == -1}) then {
        _pick = _x;
    };
} forEach _deliveries;
if (_pick isEqualTo []) exitWith { false };

_pick params ["_dId", "_routeId", "_start", "_eta", "_payload", "_srcId", "_dstId"];

// Route geometry: ambush point on a road 40-60% of the way to the dst.
private _src = [_srcId] call BO_fnc_logisticsResolveContainer;
private _dst = [_dstId] call BO_fnc_logisticsResolveContainer;
if (isNull _src || {isNull _dst}) exitWith { false };
private _sp = getPosATL _src;
private _dp = getPosATL _dst;
private _frac = 0.4 + random 0.2;
private _mid = _sp vectorAdd ((_dp vectorDiff _sp) vectorMultiply _frac);
_mid set [2, 0];
private _road = [_mid, 800] call BIS_fnc_nearestRoad;
private _ambushPos = if (!isNull _road) then { getPosATL _road } else { _mid };

private _catalog = call BO_HAL_fnc_packageCatalog;
private _idx = _catalog findIf { (_x select 0) isEqualTo "INTERDICTION" };
if (_idx < 0) exitWith { false };
private _pkg = _catalog select _idx;
if (!([_pkg] call BO_HAL_fnc_packageEligible)) exitWith { false };

private _opId = [_pkg, _ambushPos, "interdiction"] call BO_HAL_fnc_launchPackage;
if (_opId <= 0) exitWith { false };

// Stamp the delivery id on the op and extend the delivery clock once.
private _oIdx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _opId };
if (_oIdx >= 0) then { (BO_HAL_activeOps select _oIdx) set [14, [_dId]] };

private _extension = ((_eta - _start) max 300) * 0.6;
_pick set [3, _eta + _extension];
server setVariable ["BO_logisticsActiveDeliveries", _deliveries, true];

// Surface on the route's status line (the logistics dialog's existing
// error channel -- world state, not a notification).
private _routes = server getVariable ["BO_logisticsRoutes", []];
private _rIdx = _routes findIf { (_x select 0) isEqualTo _routeId };
if (_rIdx >= 0) then {
    private _route = _routes select _rIdx;
    private _stats = _route param [9, [0, 0, ""]];
    _stats set [2, "ambushed -- convoy delayed"];
    _route set [9, _stats];
    server setVariable ["BO_logisticsRoutes", _routes, true];
};

["interdict_launch", [_opId, _dId, _routeId, round _extension]] call BO_HAL_fnc_aar;
private _msg = format ["HAL interdiction op=%1 on delivery %2 (route %3), ETA +%4s", _opId, _dId, _routeId, round _extension];
BO_LOG_INFO("hal", _msg);
true
