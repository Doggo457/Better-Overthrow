#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_inferRole
 *
 * 11-class observed-kit taxonomy (addendum, revised locked decision #5).
 * Vehicle classification wins over infantry kit.
 *
 * Infantry: infantry / AT-capable / AA-capable / sniper / medic
 * Vehicle:  transport-light / transport-armed / IFV / MBT /
 *           heli-light / heli-attack / jet
 *
 * Params: 0: OBJECT unit (may be in a vehicle, may BE a vehicle)
 * Returns: STRING role tag
 */

params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith { "infantry" };

private _isMan = _unit isKindOf "Man";
private _veh = vehicle _unit;

// ---- vehicle side (wins over infantry kit) -------------------------
if (!_isMan || {_veh isNotEqualTo _unit}) exitWith {
    private _v = if (_isMan) then { _veh } else { _unit };
    private _armed = ((weapons _v) findIf {
        private _w = toLower _x;
        !(("flare" in _w) || ("horn" in _w) || ("smoke" in _w) || ("laser" in _w))
    }) >= 0;
    switch (true) do {
        case (_v isKindOf "Plane"): { "jet" };
        case (_v isKindOf "Helicopter"): { if (_armed) then { "heli-attack" } else { "heli-light" } };
        case (_v isKindOf "Tank"): { "MBT" };
        case (_v isKindOf "Wheeled_APC_F"): { "IFV" };
        case (_v isKindOf "APC_Tracked_01_base_F"): { "IFV" };
        case (_v isKindOf "Car"): { if (_armed) then { "transport-armed" } else { "transport-light" } };
        default { "transport-light" };
    };
};

// ---- infantry side --------------------------------------------------
private _sec = secondaryWeapon _unit;
if (_sec isNotEqualTo "") exitWith {
    // AT vs AA by the launcher's magazine ammo config (airLock / warheadName).
    private _isAA = false;
    private _isAT = false;
    {
        private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
        if (_ammo isNotEqualTo "") then {
            if (getNumber (configFile >> "CfgAmmo" >> _ammo >> "airLock") > 0) then { _isAA = true };
            if ((getText (configFile >> "CfgAmmo" >> _ammo >> "warheadName")) isNotEqualTo "") then { _isAT = true };
        };
    } forEach (getArray (configFile >> "CfgWeapons" >> _sec >> "magazines"));
    if (_isAA) then { "AA-capable" } else { "AT-capable" }; // launcher present: AT at minimum
};

private _prim = primaryWeapon _unit;
private _l = toLower _prim;
if (("srifle" in _l) || ("dmr" in _l) || ("gm6" in _l) || ("lrr" in _l) || ("asp1" in _l)) exitWith { "sniper" };

if (_prim isEqualTo "" && {("FirstAidKit" in (items _unit))}) exitWith { "medic" };

"infantry"
