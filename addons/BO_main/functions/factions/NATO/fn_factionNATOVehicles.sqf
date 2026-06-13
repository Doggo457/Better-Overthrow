#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOVehicles
 *
 * Server-only. Patches the per-map OT_NATO_Vehicle_ / _Vehicles_
 * pools that the per-map initVar.sqf hardcodes to BLU_F / BLU_T_F LSV +
 * MRAP classes. The faction switch in fn_initOverthrow.sqf only
 * overwrites OT_faction_NATO, not these arrays, so when the mission
 * param ot_enemy_faction is set to RHS / CUP / UK3CB the infantry
 * pool changes but the vehicle pool keeps spawning vanilla NATO
 * LSVs (Prowlers). The most visible symptom is unarmed/armed
 * Prowlers accumulating at NATO FOBs after each
 * fn_NATOMissionDeployFOB drop and each fn_NATOGroundReinforcements
 * wave (both read the scalar OT_NATO_Vehicle_Transport_Light).
 *
 * This function runs after OT_fnc_initVar finishes (so the per-map
 * defaults have been loaded AND OT_allBLUOffensiveVehicles is
 * populated) and before OT_fnc_initVirtualization begins consuming
 * the pools. When OT_faction_NATO is the per-map native faction
 * (vanilla BLU_F / BLU_T_F / BLU_W_F) the function exits early --
 * the per-map defaults are correct for vanilla.
 *
 * Pool-mining strategy mirrors fn_initNATO.sqf:179 -- filter
 * OT_allBLUOffensiveVehicles by getText "faction" against
 * OT_faction_NATO, then split by kind (wheeled cars vs armed-MRAP
 * shape via subclass/name heuristic). The MRAP-shape filter is
 * intentionally permissive: anything wheeled with a top-mounted HMG
 * or GMG-equivalent variant of the current faction qualifies. If
 * the new faction yields nothing usable we fall back to
 * OT_fallback_faction_NATO (same fallback the per-map files use).
 *
 * Affected spawn sites (read at spawn time, never reassigned):
 *   - fn_NATOMissionDeployFOB.sqf:121        (LSVs parked at FOBs)
 *   - fn_NATOGroundReinforcements.sqf:3      (LSVs delivering troops)
 *   - fn_NATOGroundPatrol.sqf:9              (Convoy patrols)
 *   - fn_factionNATO.sqf:47                  (scheduled convoys)
 *   - fn_NATOGroundSupport.sqf:10            (attack support)
 *   - fn_NATOConvoy.sqf:85                   (ambient convoys)
 *   - fn_NATOSupportRecon.sqf:126            (recon transport)
 *   - fn_spawnPoliceStationGarrison.sqf:91   (police veh fallback)
 *   - fn_dispatchPoliceReinforcements.sqf:54 (police reinforce fallback)
 */

if (!isServer) exitWith {};

private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions",
        "factionNATOVehicles: native vanilla faction, keeping per-map defaults");
};

// Resolve usable pool of offensive ground vehicles for the active
// faction, with the per-map fallback faction as a second pass.
private _pool = OT_allBLUOffensiveVehicles select {
    getText (configFile >> "CfgVehicles" >> _x >> "faction") == OT_faction_NATO
    && { !((_x isKindOf "Air") || (_x isKindOf "Ship") || (_x isKindOf "Tank")) }
};
if (_pool isEqualTo []) then {
    private _fallback = if (!isNil "OT_fallback_faction_NATO") then { OT_fallback_faction_NATO } else { "BLU_F" };
    _pool = OT_allBLUOffensiveVehicles select {
        getText (configFile >> "CfgVehicles" >> _x >> "faction") == _fallback
        && { !((_x isKindOf "Air") || (_x isKindOf "Ship") || (_x isKindOf "Tank")) }
    };
    private _msg = format ["factionNATOVehicles: no offensive vehs for %1, falling back to %2 (%3 candidates)", OT_faction_NATO, _fallback, count _pool];
    BO_LOG_WARN("factions", _msg);
};

if (_pool isEqualTo []) exitWith {
    // Last resort: keep the per-map defaults. Better LSVs than
    // crashing on selectRandom [] downstream.
    private _msg = format ["factionNATOVehicles: empty pool for %1 -- per-map defaults retained", OT_faction_NATO];
    BO_LOG_ERROR("factions", _msg);
};

// Split by shape. Cars-not-MRAP-shape are candidates for the light
// transport scalar (and unarmed convoy filler). MRAPs / armed cars
// are the support-vehicle pool. Heuristic: name contains "hmg"/"gmg"/
// "armed" / a turret config -- prefer a config-driven test where
// available, name match as fallback (RHS / CUP / UK3CB class names
// are not standardized).
private _supportPool = [];
private _lightPool   = [];
{
    private _cls = _x;
    private _isCar = _cls isKindOf "Car";
    if (!_isCar) then { continue };
    private _lower = toLower _cls;
    private _armed = ("hmg" in _lower) || ("gmg" in _lower) || ("armed" in _lower) || ("mrap" in _lower) || ("m2" in _lower) || ("kord" in _lower) || ("dshk" in _lower);
    if (_armed) then {
        _supportPool pushBack _cls;
    } else {
        _lightPool pushBack _cls;
    };
} forEach _pool;

// If splitting yielded nothing on one side, fall back to the full
// pool for that side -- better mixed than empty.
if (_supportPool isEqualTo []) then { _supportPool = +_pool };
if (_lightPool   isEqualTo []) then { _lightPool   = +_pool };

// Overwrite the LSV-bearing per-map arrays. Air entries in
// PoliceSupport (which mixes ground + air responders) are left to
// be re-added below from the existing air support pool so police
// reinforcements still get helicopter coverage where applicable.
OT_NATO_Vehicles_Convoy        = _supportPool;
OT_NATO_Vehicles_GroundSupport = _supportPool;

// Police support is CIVIL POLICE, not the army: police-station
// responses roll up in police cars, never MRAPs/armed LSVs/gunships
// (user-locked). The military escalation path is HAL's job.
private _policeCar = missionNamespace getVariable ["OT_NATO_Vehicle_Police", ""];
OT_NATO_Vehicles_PoliceSupport = if (_policeCar isNotEqualTo "") then {
    [_policeCar]
} else {
    [missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", "B_GEN_Offroad_01_gen_F"]]
};

// Light transport scalar. Convoys/reinforcements/FOB deploys read
// this one a lot, so prefer an unarmed transport when available.
OT_NATO_Vehicle_Transport_Light = selectRandom _lightPool;

private _msg = format ["factionNATOVehicles: %1 -> Convoy/GroundSupport=%2 entries, Transport_Light=%3", OT_faction_NATO, count _supportPool, OT_NATO_Vehicle_Transport_Light];
BO_LOG_INFO("factions", _msg);

publicVariable "OT_NATO_Vehicles_Convoy";
publicVariable "OT_NATO_Vehicles_GroundSupport";
publicVariable "OT_NATO_Vehicles_PoliceSupport";
publicVariable "OT_NATO_Vehicle_Transport_Light";
