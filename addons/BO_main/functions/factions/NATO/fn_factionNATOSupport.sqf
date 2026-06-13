#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOSupport
 *
 * Server-only. Re-mines the heavy-support pools (attack helis, light
 * armed helis, tanks, APCs) so QRF / air patrol / artillery + tank
 * support spawn faction-correct units.
 *
 *   - OT_NATO_Vehicles_AirSupport         (fn_NATOAirSupport:3, fn_NATOAirPatrol:12, fn_NATOScrambleHelicopter:18, fn_initArtillery:65)
 *   - OT_NATO_Vehicles_AirSupport_Small   (fn_NATOAirPatrol:11, fn_NATOScrambleHelicopter:17, fn_initArtillery:64)
 *   - OT_NATO_Vehicles_TankSupport        (fn_NATOGroundPatrol:10, fn_NATOTankSupport:11)
 *   - OT_NATO_Vehicles_APC                (fn_NATOAPCInsertion:3)
 *
 * Mining: faction + isKindOf, with armed/cargo heuristics for helis
 * (heavy = attack-classed + low cargo; small = "armed"/light-named +
 * cargo 1-6). When the small pool is empty we fall back to the heavy
 * pool to keep AirPatrol from selectRandom-ing an empty array.
 */

if (!isServer) exitWith {};
private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions", "factionNATOSupport: native vanilla, keeping per-map defaults");
};

private _activeFac = OT_faction_NATO;
private _fbFac = if (!isNil "OT_fallback_faction_NATO") then { OT_fallback_faction_NATO } else { "BLU_F" };

// Tank/APC mining must reject AA-tank chassis (Tigris/ZSU/Linebacker),
// arty (Scorcher/MLRS/Sholef), CRV variants, minefield rollers etc.
// Those are valid Tank kindOf but break the "Tank support" role.
private _rejectSubs = ["_aa_", "aa_f", "_crv", "scorcher", "mlrs", "amos", "sholef", "mine", "linebacker", "tigris", "zsu", "_aaa_"];

private _fnMineKind = {
    params ["_fac", "_kind", ["_applyReject", false]];
    private _out = [];
    {
        private _cls = configName _x;
        if (getNumber (_x >> "scope") < 2) then { continue };
        if (getText (_x >> "faction") != _fac) then { continue };
        if !(_cls isKindOf _kind) then { continue };
        if (_applyReject) then {
            private _lower = toLower _cls;
            private _reject = false;
            { if (_x in _lower) exitWith { _reject = true } } forEach _rejectSubs;
            if (_reject) then { continue };
        };
        _out pushBack _cls;
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    _out
};

// --- Tanks ---
private _tanks = [_activeFac, "Tank", true] call _fnMineKind;
if (_tanks isEqualTo []) then { _tanks = [_fbFac, "Tank", true] call _fnMineKind; };
if (_tanks isNotEqualTo []) then {
    OT_NATO_Vehicles_TankSupport = _tanks;
    publicVariable "OT_NATO_Vehicles_TankSupport";
    private _msg = format ["factionNATOSupport: TankSupport -> %1 entries", count _tanks];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOSupport: no Tank for faction -- per-map default retained");
};

// --- APC ---
private _apcs = [_activeFac, "Wheeled_APC_F", true] call _fnMineKind;
if (_apcs isEqualTo []) then { _apcs = [_activeFac, "APC", true] call _fnMineKind; };
if (_apcs isEqualTo []) then { _apcs = [_fbFac, "Wheeled_APC_F", true] call _fnMineKind; };
if (_apcs isNotEqualTo []) then {
    OT_NATO_Vehicles_APC = _apcs;
    publicVariable "OT_NATO_Vehicles_APC";
    private _msg = format ["factionNATOSupport: APC -> %1 entries", count _apcs];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOSupport: no APC for faction -- per-map default retained");
};

// --- Heli air support: heavy attack + light armed ---
private _helis = [_activeFac, "Helicopter"] call _fnMineKind;
if (_helis isEqualTo []) then { _helis = [_fbFac, "Helicopter"] call _fnMineKind; };

// Heavy: attack-classed name + low cargo. Small: light-armed name + cargo 1-6.
private _heavy = [];
private _small = [];
{
    private _cls = _x;
    private _cap = getNumber (configFile >> "CfgVehicles" >> _cls >> "transportSoldier");
    private _lower = toLower _cls;
    private _isAttack = ("attack" in _lower) || ("apache" in _lower) || ("hind" in _lower)
        || ("ah64" in _lower) || ("ah1" in _lower) || ("ah6" in _lower) || ("ka52" in _lower)
        || ("mi24" in _lower) || ("mi28" in _lower);
    private _isLightArmed = ("armed" in _lower) || ("ah6" in _lower) || ("md500" in _lower)
        || ("light_01_armed" in _lower) || ("hellcat" in _lower);
    if (_isAttack && _cap <= 2) then { _heavy pushBack _cls };
    if (_isLightArmed && _cap > 0 && _cap <= 6) then { _small pushBack _cls };
} forEach _helis;

if (_heavy isNotEqualTo []) then {
    OT_NATO_Vehicles_AirSupport = _heavy;
    publicVariable "OT_NATO_Vehicles_AirSupport";
    private _msg = format ["factionNATOSupport: AirSupport (heavy) -> %1 entries", count _heavy];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOSupport: no attack helis for faction -- per-map default retained");
};

if (_small isNotEqualTo []) then {
    OT_NATO_Vehicles_AirSupport_Small = _small;
    publicVariable "OT_NATO_Vehicles_AirSupport_Small";
    private _msg = format ["factionNATOSupport: AirSupport_Small -> %1 entries", count _small];
    BO_LOG_INFO("factions", _msg);
} else {
    if (_heavy isNotEqualTo []) then {
        // Fall back to heavy for the small role -- better gunship than nothing
        OT_NATO_Vehicles_AirSupport_Small = _heavy;
        publicVariable "OT_NATO_Vehicles_AirSupport_Small";
        BO_LOG_WARN("factions", "factionNATOSupport: AirSupport_Small fallback to heavy");
    } else {
        BO_LOG_WARN("factions", "factionNATOSupport: no AirSupport_Small + no heavy -- per-map default retained");
    };
};
