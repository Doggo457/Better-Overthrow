#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_CTRG_HUNTER
 *
 * The Hour-6 punchline (V6): a 4-man SF team helo-inserts 1.5km off
 * the search ellipse and hunts. WL >= 6, discovery level 8+. Locked D1:
 * kit looting ENABLED -- surviving the hunt is the carrot, the kit is
 * the reward (no strip, no self-destruct anywhere in this path).
 *
 * Params: 0: origin, 1: target (last-known pos), 2: catalog entry
 * Returns: [grp, veh(insertion helo), crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _sf = missionNamespace getVariable ["OT_NATO_Unit_SF", ""];
if (_sf isEqualTo "") exitWith { [grpNull, objNull, grpNull] };
private _classes = [_sf, _sf, _sf, _sf];

private _heliCls = missionNamespace getVariable ["OT_NATO_Vehicle_CTRGTransport",
    missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport_Small", ""]];
if (_heliCls isEqualTo "") exitWith { [grpNull, objNull, grpNull] };

// Insert offset from the hunt area -- they walk the last leg.
private _lz = _tgt getPos [1200 + random 600, random 360];
if (surfaceIsWater _lz) then { _lz = _tgt getPos [1500, _tgt getDir _origin] };

([_origin, _lz, _classes, _heliCls, "air", false] call BO_HAL_fnc_spawnGroup)
    params ["_grp", "_heli", "_crew"];
if (isNull _grp) exitWith { [grpNull, objNull, grpNull] };

_grp setBehaviour "STEALTH";
_grp setCombatMode "RED";
_grp setSpeedMode "NORMAL";
{ _x setSkill (missionNamespace getVariable ["BO_HAL_skillSF", 0.85]) } forEach (units _grp);
if (missionNamespace getVariable ["BO_HAL_lambsActive", false]) then {
    _grp setVariable ["lambs_danger_cqbRange", 100, false];
};

[_grp, _heli, _crew]
