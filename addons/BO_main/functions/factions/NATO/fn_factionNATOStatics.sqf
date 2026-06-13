#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOStatics
 *
 * Server-only. Re-mines OT_NATO_HMG (scalar) and
 * OT_NATO_Vehicles_StaticAAGarrison (array) so checkpoints, HQ
 * garrisons, airfield AA rings, and bo_hitAAA spawn faction-correct
 * statics when ot_enemy_faction is RHS / CUP / UK3CB.
 *
 * Consumers verified:
 *   - bo_hitCheckpoint.sqf:60, bo_prisonBreak.sqf:135
 *   - fn_spawnNATOObjective.sqf:194,212,222,229
 *   - fn_spawnNATOCheckpoint.sqf:43
 *   - fn_initNATO.sqf:217-218, 326   (HQ + airfield)
 *   - bo_hitAAA.sqf:72-73
 *
 * Mining: iterate CfgVehicles, filter by faction + isKindOf
 * StaticMGWeapon (HMG) / StaticAAWeapon (AA). When the active
 * faction yields nothing usable we fall back to
 * OT_fallback_faction_NATO so the per-map AA ring still spawns
 * something even on the weirder community mods.
 *
 * Runs after BO_fnc_factionNATOVehicles in the fn_initOverthrow
 * chain. Result is published to all clients so checkpoint spawners
 * read the patched class on the JIPer side.
 */

if (!isServer) exitWith {};
private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions", "factionNATOStatics: native vanilla, keeping per-map defaults");
};

private _activeFac = OT_faction_NATO;
private _fbFac = if (!isNil "OT_fallback_faction_NATO") then { OT_fallback_faction_NATO } else { "BLU_F" };

private _fnMine = {
    params ["_fac", "_baseKind"];
    private _out = [];
    {
        private _cls = configName _x;
        if (getNumber (_x >> "scope") < 2) then { continue };
        if (getText (_x >> "faction") != _fac) then { continue };
        if !(_cls isKindOf _baseKind) then { continue };
        _out pushBack _cls;
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    _out
};

// --- OT_NATO_HMG ---
private _hmgs = [_activeFac, "StaticMGWeapon"] call _fnMine;
if (_hmgs isEqualTo []) then { _hmgs = [_fbFac, "StaticMGWeapon"] call _fnMine; };
if (_hmgs isNotEqualTo []) then {
    OT_NATO_HMG = selectRandom _hmgs;
    publicVariable "OT_NATO_HMG";
    private _msg = format ["factionNATOStatics: HMG -> %1 (pool=%2)", OT_NATO_HMG, count _hmgs];
    BO_LOG_INFO("factions", _msg);
} else {
    private _msg = format ["factionNATOStatics: no HMG for %1/%2 -- per-map default retained", _activeFac, _fbFac];
    BO_LOG_ERROR("factions", _msg);
};

// --- OT_NATO_Vehicles_StaticAAGarrison ---
private _aas = [_activeFac, "StaticAAWeapon"] call _fnMine;
if (_aas isEqualTo []) then { _aas = [_fbFac, "StaticAAWeapon"] call _fnMine; };
if (_aas isNotEqualTo []) then {
    // Mirror per-map shape: 2 entries minimum so the AA ring has redundancy.
    private _aaSet = [];
    _aaSet pushBack (selectRandom _aas);
    _aaSet pushBack (selectRandom _aas);
    OT_NATO_Vehicles_StaticAAGarrison = _aaSet;
    publicVariable "OT_NATO_Vehicles_StaticAAGarrison";
    private _msg = format ["factionNATOStatics: AAGarrison -> %1", OT_NATO_Vehicles_StaticAAGarrison];
    BO_LOG_INFO("factions", _msg);
} else {
    private _msg = format ["factionNATOStatics: no static AA for %1/%2 -- per-map default retained", _activeFac, _fbFac];
    BO_LOG_WARN("factions", _msg);
};

// --- OT_NATO_Mortar ---
// Consumed by fn_NATOupgradeFOB.sqf when a FOB builds a mortar pit; left
// unmined it spawns a vanilla B_Mortar_01_F + vanilla crew on RHS/CUP games.
private _mortars = [_activeFac, "StaticMortar"] call _fnMine;
if (_mortars isEqualTo []) then { _mortars = [_fbFac, "StaticMortar"] call _fnMine; };
if (_mortars isNotEqualTo []) then {
    OT_NATO_Mortar = selectRandom _mortars;
    publicVariable "OT_NATO_Mortar";
    private _msg = format ["factionNATOStatics: Mortar -> %1 (pool=%2)", OT_NATO_Mortar, count _mortars];
    BO_LOG_INFO("factions", _msg);
} else {
    private _msg = format ["factionNATOStatics: no static mortar for %1/%2 -- per-map default retained", _activeFac, _fbFac];
    BO_LOG_WARN("factions", _msg);
};
