#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_launchSurge
 *
 * The sanctioned full-send (locked #30): when rebels are FIGHTING FOR
 * an area -- a live cluster, or ground NATO already lost there -- HAL
 * commits a combined-arms wave to push them out. Everything launches
 * in the SAME tick from (potentially) multiple bases and converges:
 * overwhelm, don't trickle.
 *
 * "Not overdone" is enforced by the caller's gates (fn_tick):
 *   WL >= 5, 45-min global surge cooldown, >= 2 free op slots,
 *   budget >= wave + 200 reserve, and a real trigger (3+ live
 *   sightings clustered, or 2+ recent setbacks in the area).
 * After launch the normal one-wave suppression umbrella covers the
 * area for the surge's whole lifetime -- no follow-on dribble. Each
 * element keeps its own retreat/reinforce lifecycle; if the surge
 * fails, the setbacks it stamps put the area on cooldown.
 *
 * Composition by WL (eligibility-filtered, max 3 combat elements + an
 * ISR drone; air picks dropped when AA-capable kit is in the cluster):
 *   spearhead: HEAVY_ARMOR (7+) > LIGHT_ARMOR (4+) > AIR_ATTACK (6+) > MED_SQUAD
 *   second:    AIR_ASSAULT (5+) > MED_SQUAD
 *   third:     FORTIFIED_POSITION > MED_SQUAD > LGT_INFANTRY
 *
 * Params: 0: ARRAY target pos
 * Returns: NUMBER elements launched (0 = no surge)
 */

SERVER_ONLY_RET(0);
params [["_tgt", [], [[]]]];
if (_tgt isEqualTo []) exitWith { 0 };

private _wl = round (server getVariable ["BO_warLevel", 1]);
private _catalog = call BO_HAL_fnc_packageCatalog;
private _res = server getVariable ["NATOresources", 0];

// AA anywhere in the local picture grounds the air elements.
private _aaNear = ((missionNamespace getVariable ["NATOknownTargets", []]) findIf {
    private _k = _x param [6, []];
    _k isEqualType [] && {count _k > 3} && {(_k select 3) isEqualTo "AA-capable"}
    && {((_x param [1, [0,0,0]]) distance2D _tgt) < 800}
}) != -1;

private _eligible = {
    params ["_id"];
    if (_aaNear && {_id in ["AIR_ASSAULT", "AIR_ATTACK", "AIR_CAS_DRONE"]}) exitWith { [] };
    private _i = _catalog findIf { (_x select 0) isEqualTo _id };
    if (_i < 0) exitWith { [] };
    private _e = _catalog select _i;
    if ([_e] call BO_HAL_fnc_packageEligible) then { _e } else { [] }
};

// Build the wave: first eligible from each role slot, no duplicates of
// the spearhead class in the infantry slots.
private _wave = [];
{
    private _slotPick = [];
    {
        if (_slotPick isEqualTo []) then {
            private _e = [_x] call _eligible;
            if (_e isNotEqualTo []) then { _slotPick = _e };
        };
    } forEach _x;
    if (_slotPick isNotEqualTo []) then { _wave pushBack _slotPick };
} forEach [
    ["HEAVY_ARMOR", "LIGHT_ARMOR", "AIR_ATTACK", "MED_SQUAD"],
    ["AIR_ASSAULT", "MED_SQUAD"],
    ["FORTIFIED_POSITION", "MED_SQUAD", "LGT_INFANTRY"]
];

if (count _wave < 2) exitWith { 0 }; // a surge of one is just a package

// Budget: whole wave + 200 reserve, trimming the tail if needed.
private _cost = 0;
{ _cost = _cost + (_x select 1) } forEach _wave;
while { (_cost + 200) > _res && {count _wave > 2} } do {
    private _drop = _wave deleteAt (count _wave - 1);
    _cost = _cost - (_drop select 1);
};
if ((_cost + 200) > _res) exitWith { 0 };

// Slot cap: leave one slot free for the reinforce engine.
private _free = (missionNamespace getVariable ["BO_HAL_maxConcurrentOps", 4])
    - (count (missionNamespace getVariable ["BO_HAL_activeOps", []]));
while { count _wave > (_free max 0) && {count _wave > 0} } do {
    private _drop = _wave deleteAt (count _wave - 1);
    _cost = _cost - (_drop select 1);
};
if (count _wave < 2) exitWith { 0 };

// ALL AT ONCE: every element this tick, offset aimpoints so they
// envelop the area instead of stacking on one doorstep.
private _launched = 0;
{
    private _aim = if (_launched isEqualTo 0) then { +_tgt } else {
        _tgt getPos [80 + random 120, random 360]
    };
    if (([_x, _aim, "hot"] call BO_HAL_fnc_launchPackage) > 0) then {
        _launched = _launched + 1;
    };
} forEach _wave;

if (_launched >= 2) then {
    // ISR overhead for the push (free-ish, not counted as an element).
    private _di = _catalog findIf { (_x select 0) isEqualTo "RECON_DRONE" };
    if (_di >= 0 && {[_catalog select _di] call BO_HAL_fnc_packageEligible}) then {
        [_catalog select _di, _tgt, "recon"] call BO_HAL_fnc_launchPackage;
    };
    missionNamespace setVariable ["BO_HAL_lastSurge", serverTime];
    ["surge", [_launched, _wl, _tgt]] call BO_HAL_fnc_aar;
    private _msg = format ["HAL SURGE: %1 elements committed at WL %2", _launched, _wl];
    BO_LOG_INFO("hal", _msg);
};

_launched
