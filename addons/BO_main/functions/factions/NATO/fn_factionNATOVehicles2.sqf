#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOVehicles2
 *
 * Server-only. Second-pass vehicle pool mining for the scalars and
 * arrays not covered by BO_fnc_factionNATOVehicles. Re-mines:
 *   - OT_NATO_Vehicle_HVT             (fn_spawnNATOObjective:24, fn_NATOConvoy:52)
 *   - OT_NATO_Vehicle_Police          (fn_NATOsendGendarmerie:37, fn_spawnPoliceStationGarrison:91, fn_dispatchPoliceReinforcements:54)
 *   - OT_NATO_Vehicle_Boat_Small      (fn_NATOSeaSupport:5)
 *   - OT_NATO_Vehicle_Transport       (bo_paydayConvoyAmbush, bo_sabotageDepot, bo_protectDefector, bo_stealNATOTruck, fn_NATOGroundForces)
 *
 * HVT: prefer Car kindOf with armed MRAP-shape (top HMG). Falls back
 * to any armed Car for the faction.
 * Police: prefer unarmed Car. Falls back to OT_NATO_Vehicle_Transport_Light.
 * Boat: faction + isKindOf "Ship" + armed.
 * Transport (array): faction + isKindOf "Truck_F" - exclude HMG-armed beds.
 *
 * Depends on BO_fnc_factionNATOVehicles having populated
 * OT_NATO_Vehicle_Transport_Light so the police fallback has a
 * sane non-nil class to point at when no unarmed Car exists.
 */

if (!isServer) exitWith {};
private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions", "factionNATOVehicles2: native vanilla, keeping per-map defaults");
};

private _activeFac = OT_faction_NATO;
private _fbFac = if (!isNil "OT_fallback_faction_NATO") then { OT_fallback_faction_NATO } else { "BLU_F" };

private _fnMineKind = {
    params ["_fac", "_kind"];
    private _out = [];
    {
        private _cls = configName _x;
        if (getNumber (_x >> "scope") < 2) then { continue };
        if (getText (_x >> "faction") != _fac) then { continue };
        if !(_cls isKindOf _kind) then { continue };
        _out pushBack _cls;
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    _out
};

private _isArmed = {
    params ["_cls"];
    private _lower = toLower _cls;
    ("hmg" in _lower) || ("gmg" in _lower) || ("armed" in _lower)
    || ("mrap" in _lower) || ("m2" in _lower) || ("kord" in _lower)
    || ("dshk" in _lower)
};

// --- OT_NATO_Vehicle_HVT (armed Car / MRAP) ---
private _cars = [_activeFac, "Car"] call _fnMineKind;
if (_cars isEqualTo []) then { _cars = [_fbFac, "Car"] call _fnMineKind; };
private _armedCars = _cars select { [_x] call _isArmed };
if (_armedCars isNotEqualTo []) then {
    OT_NATO_Vehicle_HVT = selectRandom _armedCars;
    publicVariable "OT_NATO_Vehicle_HVT";
    private _msg = format ["factionNATOVehicles2: HVT -> %1", OT_NATO_Vehicle_HVT];
    BO_LOG_INFO("factions", _msg);
} else {
    private _msg = "factionNATOVehicles2: no armed Car for HVT -- per-map default retained";
    BO_LOG_WARN("factions", _msg);
};

// --- OT_NATO_Vehicle_Police (unarmed Car preferred) ---
private _unarmedCars = _cars select { !([_x] call _isArmed) };
if (_unarmedCars isNotEqualTo []) then {
    OT_NATO_Vehicle_Police = selectRandom _unarmedCars;
    publicVariable "OT_NATO_Vehicle_Police";
    private _msg = format ["factionNATOVehicles2: Police -> %1", OT_NATO_Vehicle_Police];
    BO_LOG_INFO("factions", _msg);
} else {
    // Fall back to light transport scalar (already remined by factionNATOVehicles)
    if (!isNil "OT_NATO_Vehicle_Transport_Light") then {
        OT_NATO_Vehicle_Police = OT_NATO_Vehicle_Transport_Light;
        publicVariable "OT_NATO_Vehicle_Police";
        private _msg = format ["factionNATOVehicles2: Police -> fallback to Transport_Light %1", OT_NATO_Vehicle_Police];
        BO_LOG_WARN("factions", _msg);
    } else {
        BO_LOG_ERROR("factions", "factionNATOVehicles2: no unarmed Car + Transport_Light nil -- per-map default retained");
    };
};

// --- OT_NATO_Vehicle_Boat_Small (armed Ship) ---
private _ships = [_activeFac, "Ship"] call _fnMineKind;
if (_ships isEqualTo []) then { _ships = [_fbFac, "Ship"] call _fnMineKind; };
private _armedShips = _ships select { [_x] call _isArmed };
private _shipPool = if (_armedShips isNotEqualTo []) then { _armedShips } else { _ships };
if (_shipPool isNotEqualTo []) then {
    OT_NATO_Vehicle_Boat_Small = selectRandom _shipPool;
    publicVariable "OT_NATO_Vehicle_Boat_Small";
    private _msg = format ["factionNATOVehicles2: Boat_Small -> %1", OT_NATO_Vehicle_Boat_Small];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOVehicles2: no Ship for faction -- per-map default retained");
};

// --- OT_NATO_Vehicle_Transport (truck array) ---
private _trucks = [_activeFac, "Truck_F"] call _fnMineKind;
if (_trucks isEqualTo []) then { _trucks = [_fbFac, "Truck_F"] call _fnMineKind; };
// Exclude armed-bed trucks: prefer cargo/covered/transport variants
private _cargoTrucks = _trucks select { !([_x] call _isArmed) };
if (_cargoTrucks isEqualTo []) then { _cargoTrucks = _trucks };
if (_cargoTrucks isNotEqualTo []) then {
    // Keep at most 4 unique entries (mirror per-map array shape)
    private _seen = [];
    {
        if !(_x in _seen) then { _seen pushBack _x };
        if (count _seen >= 4) exitWith {};
    } forEach _cargoTrucks;
    OT_NATO_Vehicle_Transport = _seen;
    publicVariable "OT_NATO_Vehicle_Transport";
    private _msg = format ["factionNATOVehicles2: Transport -> %1", OT_NATO_Vehicle_Transport];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_ERROR("factions", "factionNATOVehicles2: no Truck_F for faction -- per-map default retained");
};
