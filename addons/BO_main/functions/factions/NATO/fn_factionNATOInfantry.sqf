#include "\overthrow_main\headers\log_macros.hpp"
/*
 * BO_fnc_factionNATOInfantry
 *
 * Server-only. Per-map HAL anti-armor + spec-ops role re-miner. Covers
 * three HAL Day-1 vars (OT_NATO_Unit_AT, _AT_Heavy, _SF) so HAL's
 * anti-armor + spec-ops pulls resolve on RHS / CUP / UK3CB factions.
 *
 * POLICE ROLES ARE INTENTIONALLY NOT TOUCHED. OT_NATO_Unit_Police /
 * _Police_Heavy / _PoliceCommander / _PoliceCommander_Heavy /
 * _PoliceMedic_Heavy stay at the per-map Apex Gendarmerie defaults
 * (B_Gen_*). The Gendarmerie classes are DLC-tied, not military-
 * faction-tied -- they work the same whether the player picks vanilla
 * BLU_F, RHS USAF, CUP USMC, or UK3CB BAF. Police station garrisons
 * should look like police, not the active military faction.
 *
 * AT detection covers RHS (riflemanat / _atrifleman), CUP (_LAT, _AT_),
 * UK3CB (_LAT, _AT_), vanilla (_LAT_F, _AT_F), and Titan-tagged classes
 * (excluding Titan-AA).
 */

if (!isServer) exitWith {};

private _vanilla = ["BLU_F", "BLU_T_F", "BLU_W_F"];
if (OT_faction_NATO in _vanilla) exitWith {
    BO_LOG_DEBUG("factions", "factionNATOInfantry: native vanilla, keeping per-map defaults");
};

private _activeFac = OT_faction_NATO;
private _fbFac = if (!isNil "OT_fallback_faction_NATO") then { OT_fallback_faction_NATO } else { "BLU_F" };

private _fnMineMen = {
    params ["_fac"];
    private _out = [];
    {
        private _cls = configName _x;
        if (getNumber (_x >> "scope") < 2) then { continue };
        if (getText (_x >> "faction") != _fac) then { continue };
        if !(_cls isKindOf "CAManBase") then { continue };
        _out pushBack _cls;
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    _out
};

private _men = [_activeFac] call _fnMineMen;
if (_men isEqualTo []) then {
    _men = [_fbFac] call _fnMineMen;
    private _wmsg = format ["factionNATOInfantry: empty pool for %1, falling back to %2 (%3 candidates)", _activeFac, _fbFac, count _men];
    BO_LOG_WARN("factions", _wmsg);
};

if (_men isEqualTo []) exitWith {
    BO_LOG_ERROR("factions", "factionNATOInfantry: no CAManBase units for faction or fallback -- per-map defaults retained");
};

private _tlFallback = if (!isNil "OT_NATO_Unit_TeamLeader") then { OT_NATO_Unit_TeamLeader } else { _men select 0 };

// AT roles -- covers RHS (riflemanat / _atrifleman), CUP (_LAT, _AT_),
// UK3CB (_LAT, _AT_), vanilla (_LAT_F, _AT_F), and Titan-tagged classes
// (excluding Titan-AA variants).
private _idxLAT     = _men findIf {
    private _l = toLower _x;
    ("_lat" in _l) || (("javelin" in _l) && {"_at" in _l})
};
private _idxHeavyAT = _men findIf {
    private _l = toLower _x;
    ("riflemanat" in _l) || ("_atrifleman" in _l) || ("_at_f" in _l)
        || ("_at_" in _l) || (("titan" in _l) && {!("aa" in _l)})
};

// Heavy resolves first so light can fall back to it: a faction with only a
// heavy AT (e.g. RHS USMC has riflemanat but no separate LAT) should field
// that AT rifleman for both roles, NOT a vanilla leader. Only when neither
// AT class exists do we fall back to the (now faction-correct) leader.
private _atHeavy = if (_idxHeavyAT >= 0) then { _men select _idxHeavyAT } else { _tlFallback };
private _atLight = if (_idxLAT     >= 0) then { _men select _idxLAT     } else { _atHeavy };

// SF roles -- RHS (_sf / _delta / _recon), CUP (_sf / _recon / _frogman),
// UK3CB (_sas / _recon), vanilla (_ctrg).
private _idxSF = _men findIf {
    private _l = toLower _x;
    ("_sf" in _l) || ("ctrg" in _l) || ("delta" in _l) || ("recon" in _l) || ("_sas" in _l) || ("frogman" in _l)
};
private _sf = if (_idxSF >= 0) then { _men select _idxSF } else { _tlFallback };

OT_NATO_Unit_AT       = _atLight;
OT_NATO_Unit_AT_Heavy = _atHeavy;
OT_NATO_Unit_SF       = _sf;

publicVariable "OT_NATO_Unit_AT";
publicVariable "OT_NATO_Unit_AT_Heavy";
publicVariable "OT_NATO_Unit_SF";

private _msg = format ["factionNATOInfantry: %1 -> AT=%2 ATH=%3 SF=%4 (police stays Gendarmerie)",
    _activeFac, _atLight, _atHeavy, _sf];
BO_LOG_INFO("factions", _msg);
