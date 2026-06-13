#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_doctrineNote
 *
 * Adaptive counter-doctrine COLLECTOR. Every NATO casualty teaches the
 * network something about how the resistance fights; each lesson is a
 * cheap, event-driven sample taken at the moment of the kill:
 *
 *   range      victim->killer distance, bucketed
 *              [0-50 | 50-150 | 150-300 | 300-600 | 600+]
 *   darkness   sunOrMoon < 0.5 at time of kill
 *   weapon     sniper/DMR, MG, launcher, explosive/none, + suppressor
 *              fitted (classified from the killer's synced loadout --
 *              works for remote players on dedicated)
 *   mobility   killer's vehicle class: none / car / armor / air
 *   terrain    urban (within 350m of a town center) vs rural
 *   formation  living resistance within 60m of the killer (swarm vs
 *              lone-wolf), sampled per kill
 *   per-UID    kill tally per player (MP: shows WHO is teaching them)
 *
 * Separate "ied" mode tallies seen explosive emplacements (hooked from
 * fn_explosivesPlacedHandler).
 *
 * Counts live in `server var "BO_HAL_doctrine"` (auto-persisted across
 * save/load -- the network REMEMBERS across sessions) and decay x0.997
 * per strategic tick (fn_doctrineTraits), so a change of playstyle
 * fades the old profile over days, not instantly.
 *
 * Layout (flat array, version-tagged):
 *  0 ver  1 kills  2..6 rangeBuckets  7 night
 *  8 wSniper 9 wMG 10 wLauncher 11 wExplosive 12 wSuppressed
 *  13 vCar 14 vArmor 15 vAir  16 urban
 *  17 alliesSum 18 allySamples 19 loneKills  20 ied
 *  21 perUid [[uid, kills], ...]
 *
 * Params (mode "kill"): 0: "kill", 1: OBJECT killer, 2: OBJECT victim
 * Params (mode "ied"):  0: "ied"
 */

if (!isServer) exitWith {};

params [["_mode", "kill", [""]], ["_killer", objNull, [objNull]], ["_victim", objNull, [objNull]]];

private _d = server getVariable ["BO_HAL_doctrine", []];
if (_d isEqualTo [] || {(_d param [0, 0]) isNotEqualTo 1}) then {
    _d = [1, 0, 0,0,0,0,0, 0, 0,0,0,0,0, 0,0,0, 0, 0,0,0, 0, []];
};

if (_mode isEqualTo "ied") exitWith {
    _d set [20, (_d select 20) + 1];
    server setVariable ["BO_HAL_doctrine", _d];
};

if (isNull _killer || {isNull _victim}) exitWith {};

_d set [1, (_d select 1) + 1];

// ---- range ------------------------------------------------------------
private _range = _victim distance _killer;
private _rIdx = switch (true) do {
    case (_range < 50):  { 2 };
    case (_range < 150): { 3 };
    case (_range < 300): { 4 };
    case (_range < 600): { 5 };
    default              { 6 };
};
_d set [_rIdx, (_d select _rIdx) + 1];

// ---- darkness -----------------------------------------------------------
if (sunOrMoon < 0.5) then { _d set [7, (_d select 7) + 1] };

// ---- weapon class (synced loadout works for remote killers) -------------
private _wpn = currentWeapon _killer;
if (_wpn isEqualTo "") then { _wpn = primaryWeapon _killer };
private _wl = toLower _wpn;
private _secondary = secondaryWeapon _killer;
switch (true) do {
    case (_wpn isEqualTo ""): { _d set [11, (_d select 11) + 1] };  // no gun = traps/explosives
    case (_wl isEqualTo toLower _secondary && {_secondary isNotEqualTo ""}): {
        _d set [10, (_d select 10) + 1]
    };
    case (("srifle" in _wl) || ("dmr" in _wl) || ("gm6" in _wl) || ("lrr" in _wl)
        || ("m107" in _wl) || ("svd" in _wl) || ("m24" in _wl) || ("awm" in _wl)): {
        _d set [8, (_d select 8) + 1]
    };
    case (("lmg" in _wl) || ("mmg" in _wl) || ("zafir" in _wl) || ("pkm" in _wl)
        || ("pkp" in _wl) || ("m249" in _wl) || ("m240" in _wl) || ("mg42" in _wl)
        || ("minigun" in _wl)): {
        _d set [9, (_d select 9) + 1]
    };
    default {};
};
private _items = toLower ((primaryWeaponItems _killer) joinString " ");
if (("snds" in _items) || ("suppress" in _items) || ("silenc" in _items)
    || ("sd_" in _items) || ("_sd" in _items)) then {
    _d set [12, (_d select 12) + 1];
};

// ---- mobility -------------------------------------------------------------
private _kv = vehicle _killer;
if (_kv isNotEqualTo _killer) then {
    switch (true) do {
        case (_kv isKindOf "Tank");
        case (_kv isKindOf "Wheeled_APC_F"): { _d set [14, (_d select 14) + 1] };
        case (_kv isKindOf "Air"):           { _d set [15, (_d select 15) + 1] };
        case (_kv isKindOf "Car"):           { _d set [13, (_d select 13) + 1] };
        default {};
    };
};

// ---- terrain ---------------------------------------------------------------
private _town = (getPosATL _victim) call OT_fnc_nearestTown;
if (!isNil "_town" && {_town isEqualType ""} && {_town isNotEqualTo ""}) then {
    private _tp = server getVariable [_town, []];
    if (_tp isNotEqualTo [] && {(_tp distance2D _victim) < 350}) then {
        _d set [16, (_d select 16) + 1];
    };
};

// ---- formation ---------------------------------------------------------------
private _allies = ({
    alive _x && {_x isNotEqualTo _killer} && {side group _x isEqualTo independent}
} count ((getPosATL _killer) nearEntities [["CAManBase"], 60]));
_d set [17, (_d select 17) + _allies];
_d set [18, (_d select 18) + 1];
if (_allies isEqualTo 0) then { _d set [19, (_d select 19) + 1] };

// ---- per-player ----------------------------------------------------------------
if (isPlayer _killer) then {
    private _uid = getPlayerUID _killer;
    private _per = _d select 21;
    private _i = _per findIf { (_x select 0) isEqualTo _uid };
    if (_i >= 0) then {
        private _e = _per select _i;
        _e set [1, (_e select 1) + 1];
    } else {
        _per pushBack [_uid, 1];
    };
};

server setVariable ["BO_HAL_doctrine", _d];
