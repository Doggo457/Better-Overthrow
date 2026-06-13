#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOAir
 *
 * Server-only. Re-mines the air vehicle pools so airfield garrisons,
 * recon inserts, FOB deploys, and the defector exfil heli are
 * faction-correct.
 *   - OT_NATO_Vehicle_AirTransport            (array, fn_NATOGroundForces:5, fn_NATOGroundReinforcements:5)
 *   - OT_NATO_Vehicle_AirTransport_Small      (scalar, fn_NATOMissionReconInsert:71, fn_NATOMissionDeployFOB:53, fn_NATOSupportSniper:35)
 *   - OT_NATO_Vehicle_AirTransport_Large      (scalar, bo_protectDefector:301)
 *   - OT_NATO_Vehicle_CTRGTransport           (scalar, fn_CTRGsupport:41, fn_NATOSupportRecon:53)
 *   - OT_NATO_Vehicles_AirGarrison            (array of [cls,weight], fn_initNATO:304)
 *   - OT_NATO_Vehicles_JetGarrison            (array of [cls,weight], fn_initNATO:228)
 *   - OT_NATO_Vehicles_ReconDrone             (scalar, fn_NATOcounterObjectives:99, fn_mapHandler:140)
 *
 * Cargo capacity test via transportSoldier config entry; small <= 6,
 * mid 7-10, large > 10. Armed-attack helis (transportSoldier <= 0)
 * are excluded from transport variants -- they belong in
 * BO_fnc_factionNATOSupport.
 */

if (!isServer) exitWith {};
private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions", "factionNATOAir: native vanilla, keeping per-map defaults");
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

private _helis = [_activeFac, "Helicopter"] call _fnMineKind;
if (_helis isEqualTo []) then { _helis = [_fbFac, "Helicopter"] call _fnMineKind; };

// Sort by cargo capacity
private _smallHelis = [];
private _midHelis = [];
private _largeHelis = [];
private _attackHelis = [];
{
    private _cls = _x;
    private _cap = getNumber (configFile >> "CfgVehicles" >> _cls >> "transportSoldier");
    if (_cap <= 0) then {
        _attackHelis pushBack _cls;
    } else {
        if (_cap <= 6)  then { _smallHelis pushBack _cls };
        if (_cap > 6 && _cap <= 10) then { _midHelis pushBack _cls };
        if (_cap > 10) then { _largeHelis pushBack _cls };
    };
} forEach _helis;

// --- OT_NATO_Vehicle_AirTransport_Small + CTRG (both share small lift) ---
private _pickSmall = if (_smallHelis isNotEqualTo []) then {
    selectRandom _smallHelis
} else {
    if (_midHelis isNotEqualTo []) then { selectRandom _midHelis } else { "" }
};
if (_pickSmall != "") then {
    OT_NATO_Vehicle_AirTransport_Small = _pickSmall;
    publicVariable "OT_NATO_Vehicle_AirTransport_Small";
    OT_NATO_Vehicle_CTRGTransport = _pickSmall;  // CTRG is vanilla-Apex only; reuse small lift.
    publicVariable "OT_NATO_Vehicle_CTRGTransport";
    private _msg = format ["factionNATOAir: AirTransport_Small/CTRG -> %1", _pickSmall];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOAir: no Helicopter for AirTransport_Small -- per-map default retained");
};

// --- OT_NATO_Vehicle_AirTransport_Large ---
private _pickLarge = if (_largeHelis isNotEqualTo []) then {
    selectRandom _largeHelis
} else {
    if (_midHelis isNotEqualTo []) then { selectRandom _midHelis } else { _pickSmall }
};
if (_pickLarge != "") then {
    OT_NATO_Vehicle_AirTransport_Large = _pickLarge;
    publicVariable "OT_NATO_Vehicle_AirTransport_Large";
    private _msg = format ["factionNATOAir: AirTransport_Large -> %1", _pickLarge];
    BO_LOG_INFO("factions", _msg);
};

// --- OT_NATO_Vehicle_AirTransport (array, mid + small mix) ---
private _transportPool = _midHelis + _smallHelis;
if (_transportPool isNotEqualTo []) then {
    OT_NATO_Vehicle_AirTransport = _transportPool;
    publicVariable "OT_NATO_Vehicle_AirTransport";
    private _msg = format ["factionNATOAir: AirTransport array -> %1 entries", count _transportPool];
    BO_LOG_INFO("factions", _msg);
};

// --- OT_NATO_Vehicles_AirGarrison (array of [cls, weight]) ---
if (_helis isNotEqualTo []) then {
    private _airGar = [];
    { _airGar pushBack [_x, 1] } forEach _helis;
    OT_NATO_Vehicles_AirGarrison = _airGar;
    publicVariable "OT_NATO_Vehicles_AirGarrison";
    private _msg = format ["factionNATOAir: AirGarrison -> %1 entries", count _airGar];
    BO_LOG_INFO("factions", _msg);
};

// --- OT_NATO_Vehicles_JetGarrison (array of [cls, weight]) ---
private _planes = [_activeFac, "Plane"] call _fnMineKind;
if (_planes isEqualTo []) then { _planes = [_fbFac, "Plane"] call _fnMineKind; };
private _nonUAVplanes = _planes select { !(_x isKindOf "UAV") };
if (_nonUAVplanes isNotEqualTo []) then {
    private _jetGar = [];
    { _jetGar pushBack [_x, 1] } forEach _nonUAVplanes;
    OT_NATO_Vehicles_JetGarrison = _jetGar;
    publicVariable "OT_NATO_Vehicles_JetGarrison";
    private _msg = format ["factionNATOAir: JetGarrison -> %1 entries", count _jetGar];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOAir: no non-UAV Plane for JetGarrison -- per-map default retained");
};

// --- OT_NATO_Vehicles_AirWingedSupport (scramble / CAS strike jet) ---
// Consumed by fn_NATOScrambleJet.sqf + fn_reclaimAssault.sqf. Left unmined it
// scrambles a vanilla B_Plane_Fighter_01_F on RHS/CUP games. Prefer armed
// fighter/CAS-named planes from the faction's plane pool; keep per-map
// default only when the faction genuinely fields no fixed-wing.
if (_nonUAVplanes isNotEqualTo []) then {
    private _strike = _nonUAVplanes select {
        private _l = toLower _x;
        ("fighter" in _l) || ("cas" in _l) || ("f18" in _l) || ("f_18" in _l) || ("a10" in _l)
            || ("a_10" in _l) || ("av8" in _l) || ("harrier" in _l) || ("su25" in _l) || ("su_25" in _l)
            || ("attack" in _l) || ("jet" in _l)
    };
    private _wing = if (_strike isNotEqualTo []) then { _strike } else { _nonUAVplanes };
    OT_NATO_Vehicles_AirWingedSupport = _wing;
    publicVariable "OT_NATO_Vehicles_AirWingedSupport";
    private _msg = format ["factionNATOAir: AirWingedSupport -> %1 entries", count _wing];
    BO_LOG_INFO("factions", _msg);
} else {
    BO_LOG_WARN("factions", "factionNATOAir: no fixed-wing for AirWingedSupport -- per-map default retained");
};

// --- OT_NATO_Vehicles_ReconDrone (UAV) ---
private _uavs = [_activeFac, "UAV"] call _fnMineKind;
if (_uavs isEqualTo []) then { _uavs = [_fbFac, "UAV"] call _fnMineKind; };
if (_uavs isNotEqualTo []) then {
    private _nonCAS = _uavs select { !("cas" in toLower _x) };
    private _pick = if (_nonCAS isNotEqualTo []) then { selectRandom _nonCAS } else { selectRandom _uavs };
    OT_NATO_Vehicles_ReconDrone = _pick;
    publicVariable "OT_NATO_Vehicles_ReconDrone";
    private _msg = format ["factionNATOAir: ReconDrone -> %1", _pick];
    BO_LOG_INFO("factions", _msg);

    // OT_NATO_Vehicles_CASDrone -- the armed UAV. Prefer a CAS/armed-named
    // drone; only if the faction has none does the package stay on the
    // vanilla default (and it is eligibility-gated anyway).
    private _casUavs = _uavs select { private _l = toLower _x; ("cas" in _l) || ("armed" in _l) || ("dynamicloadout" in _l) };
    if (_casUavs isNotEqualTo []) then {
        OT_NATO_Vehicles_CASDrone = selectRandom _casUavs;
        publicVariable "OT_NATO_Vehicles_CASDrone";
        private _cmsg = format ["factionNATOAir: CASDrone -> %1", OT_NATO_Vehicles_CASDrone];
        BO_LOG_INFO("factions", _cmsg);
    };
} else {
    BO_LOG_WARN("factions", "factionNATOAir: no UAV for faction -- per-map default retained");
};
