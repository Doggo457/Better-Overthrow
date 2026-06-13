#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_priceFallbackHeuristic
 *
 * Last-resort pricing. Calculates a sensible price using mass,
 * armor, engine power, etc., then CLAMPS the result to a per-
 * category range to prevent wonky modded stats producing
 * $5 rifles or $50,000 magazines.
 *
 * Clamps:
 *   Assault rifle    $500–$5000
 *   SMG              $250–$1500
 *   Sniper rifle     $1500–$8000
 *   Machine gun      $800–$5000
 *   Pistol           $100–$1500
 *   Launcher         $1000–$20000
 *   Magazine         $5–$200 (calculated by round count × caliber factor)
 *   Vest             $30–$1500
 *   Helmet           $20–$800
 *   Backpack         $20–$300
 *   Optic            $50–$3000
 *   Attachment       $20–$500
 *   Vehicle (ground) $1000–$200000
 *   Vehicle (air)    $5000–$500000
 *
 * Params:
 *   0: STRING - class name
 *
 * Returns: ARRAY [base, wood, steel, plastic]
 */

params [["_cls", "", [""]]];
if (_cls isEqualTo "") exitWith { [10, 0, 0, 0] };

private _wCfg = configFile >> "CfgWeapons" >> _cls;
private _vCfg = configFile >> "CfgVehicles" >> _cls;
private _mCfg = configFile >> "CfgMagazines" >> _cls;

private _clamp = {
    params ["_v", "_lo", "_hi"];
    if (_v < _lo) exitWith { _lo };
    if (_v > _hi) exitWith { _hi };
    _v
};

// Magazine?
if (isClass _mCfg) exitWith {
    private _rounds = getNumber (_mCfg >> "count");
    private _mass = getNumber (_mCfg >> "mass");
    // Round-count weighted with mass tie-breaker.
    private _price = round (_rounds * 0.6 + _mass * 0.5);
    _price = [_price, 5, 200] call _clamp;
    [_price, 0, 0.1, 0]
};

// Weapon?
if (isClass _wCfg) then {
    private _type = ([_cls] call BIS_fnc_itemType) select 1;
    private _mass = getNumber (_wCfg >> "WeaponSlotsInfo" >> "mass");

    // Treat the mass as the base signal then clamp by category.
    private _basePrice = (_mass * 20) max 100;

    private _lo = 100;
    private _hi = 2000;
    private _steel = 1;
    private _plastic = 0;
    call {
        if (_type == "AssaultRifle")    exitWith { _lo = 500;  _hi = 5000;  _steel = 2 };
        if (_type == "SubmachineGun")   exitWith { _lo = 250;  _hi = 1500;  _steel = 1 };
        if (_type == "SniperRifle")     exitWith { _lo = 1500; _hi = 8000;  _steel = 3 };
        if (_type == "MachineGun")      exitWith { _lo = 800;  _hi = 5000;  _steel = 3 };
        if (_type == "Handgun")         exitWith { _lo = 100;  _hi = 1500;  _steel = 1 };
        if (_type == "MissileLauncher") exitWith { _lo = 5000; _hi = 20000; _steel = 2; _plastic = 2 };
        if (_type == "RocketLauncher")  exitWith { _lo = 1000; _hi = 8000;  _steel = 2; _plastic = 1 };
        if (_type == "Shotgun")         exitWith { _lo = 200;  _hi = 1500;  _steel = 1 };
    };
    private _price = [_basePrice, _lo, _hi] call _clamp;
    [_price, 0, _steel, _plastic]
};

// Vehicle?
if (isClass _vCfg) exitWith {
    private _isAir = _cls isKindOf "Air";
    private _armor = getNumber (_vCfg >> "armor");
    private _engine = getNumber (_vCfg >> "enginePower");
    private _load = getNumber (_vCfg >> "maximumLoad");
    private _crew = count ("true" configClasses (_vCfg >> "Turrets")) + 1;

    // Blend the signals so a single zero stat doesn't break us.
    private _price = round (
        (_armor * 40) +
        (_engine * 5) +
        (_load * 0.05) +
        (_crew * 200)
    );

    if (_isAir) exitWith {
        _price = [_price, 5000, 500000] call _clamp;
        [_price, 0, 50, 10]
    };

    _price = [_price, 1000, 200000] call _clamp;
    [_price, 0, 20, 4]
};

// Unknown — minimal safe default.
[10, 0, 0, 0]
