#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOGarrisonTemplates
 *
 * Re-builds OT_NATO_StaticGarrison_LevelOne/Two/Three from the now-
 * mined statics + armed MRAPs. Must run AFTER factionNATOStatics and
 * factionNATOVehicles2.
 *
 * Consumers: fn_initNATO.sqf:191-198, fn_NATOupgradeFOB.sqf:28.
 *
 * Mirrors per-map shape:
 *   Level1 = [HMG]
 *   Level2 = [HMG, HMG, GMG, MRAP_hmg]
 *   Level3 = [StaticAT, StaticAA, HMG, HMG, GMG, MRAP_hmg, MRAP_gmg]
 *
 * If the active faction has no GMG variant we substitute another HMG.
 * If no StaticAT we drop that slot. Level3 will always include MRAPs
 * twice -- this matches the per-map shape (one HMG MRAP + one GMG MRAP)
 * but we only have one HVT scalar, so both slots use the same class.
 * In practice the spawner randomizes the loadout so visual variety is
 * preserved.
 */

if (!isServer) exitWith {};
private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions", "factionNATOGarrisonTemplates: native vanilla, keeping per-map defaults");
};

private _activeFac = OT_faction_NATO;
private _hmg = if (!isNil "OT_NATO_HMG") then { OT_NATO_HMG } else { "" };
private _mrap = if (!isNil "OT_NATO_Vehicle_HVT") then { OT_NATO_Vehicle_HVT } else { "" };

if (_hmg isEqualTo "") exitWith {
    BO_LOG_ERROR("factions", "factionNATOGarrisonTemplates: OT_NATO_HMG nil -- skipping rebuild");
};

// Mine a GMG variant -- prefer name-tagged "gmg" / "grenade".
private _gmg = _hmg;  // fallback to HMG
private _stop = false;
{
    if (_stop) exitWith {};
    private _cls = configName _x;
    if (getNumber (_x >> "scope") < 2) then { continue };
    if (getText (_x >> "faction") != _activeFac) then { continue };
    if !(_cls isKindOf "StaticMGWeapon") then { continue };
    private _lower = toLower _cls;
    if (("gmg" in _lower) || ("grenade" in _lower)) then {
        _gmg = _cls;
        _stop = true;
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

// Mine a StaticAT
private _at = "";
private _stopAT = false;
{
    if (_stopAT) exitWith {};
    private _cls = configName _x;
    if (getNumber (_x >> "scope") < 2) then { continue };
    if (getText (_x >> "faction") != _activeFac) then { continue };
    if (_cls isKindOf "StaticATWeapon") then {
        _at = _cls;
        _stopAT = true;
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

private _aa = if (!isNil "OT_NATO_Vehicles_StaticAAGarrison" && { (count OT_NATO_Vehicles_StaticAAGarrison) > 0 }) then {
    OT_NATO_Vehicles_StaticAAGarrison select 0
} else {
    ""
};

OT_NATO_StaticGarrison_LevelOne = [_hmg];
private _l2 = [_hmg, _hmg, _gmg];
if (_mrap != "") then { _l2 pushBack _mrap };
OT_NATO_StaticGarrison_LevelTwo = _l2;

private _l3 = [];
if (_at != "") then { _l3 pushBack _at };
if (_aa != "") then { _l3 pushBack _aa };
_l3 append [_hmg, _hmg, _gmg];
if (_mrap != "") then { _l3 append [_mrap, _mrap] };
OT_NATO_StaticGarrison_LevelThree = _l3;

publicVariable "OT_NATO_StaticGarrison_LevelOne";
publicVariable "OT_NATO_StaticGarrison_LevelTwo";
publicVariable "OT_NATO_StaticGarrison_LevelThree";

private _msg = format ["factionNATOGarrisonTemplates: L1=%1 L2=%2 L3=%3", OT_NATO_StaticGarrison_LevelOne, OT_NATO_StaticGarrison_LevelTwo, OT_NATO_StaticGarrison_LevelThree];
BO_LOG_INFO("factions", _msg);
