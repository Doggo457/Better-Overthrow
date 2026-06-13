#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initPricing
 *
 * Re-run the price resolver over every recognized weapon, magazine,
 * vest, helmet, attachment, optic, vehicle, and accessory class in
 * the loaded mod-set after OT's own price loader has finished.
 *
 * The resolver layers:
 *   1. OT hardcoded price (already in `cost` namespace)
 *   2. BO curated mod packs (loaded from prices/*.sqf)
 *   3. Mod-author opt-in attribute (BO_basePrice config)
 *   4. Vanilla equivalent by magazine compatibility
 *   5. Faction average
 *   6. Improved heuristic with category clamps
 *
 * Steps 2 and 3 happen here at init. Steps 4-6 happen lazily at
 * runtime inside BO_fnc_resolvePrice when an item without a stored
 * price is first looked up.
 *
 * Also loads admin overrides from BO_priceOverrides server var.
 */

SERVER_ONLY;

private _t0 = diag_tickTime;

// 1. Load curated mod packs.
private _packs = ["rhs", "cup", "3cb"];
private _packLoaded = 0;
{
    private _pack = _x;
    private _packPath = format ["\overthrow_main\prices\%1.sqf", _pack];
    if (fileExists _packPath) then {
        [_pack, _packPath] call BO_fnc_loadPricePack;
        _packLoaded = _packLoaded + 1;
    };
} forEach _packs;

// 2. Mod-author opt-in attribute scan.
//    Walk every weapon and vehicle config that declares BO_basePrice
//    and write that into the `cost` namespace.
private _attrLoaded = 0;
{
    private _name = configName _x;
    private _val = getNumber (_x >> "BO_basePrice");
    if (_val > 0) then {
        cost setVariable [_name, [_val, 0, 0, 0], true];
        _attrLoaded = _attrLoaded + 1;
    };
} forEach ("getNumber (_x >> 'BO_basePrice') > 0" configClasses (configFile >> "CfgWeapons"));

{
    private _name = configName _x;
    private _val = getNumber (_x >> "BO_basePrice");
    if (_val > 0) then {
        cost setVariable [_name, [_val, 0, 0, 0], true];
        _attrLoaded = _attrLoaded + 1;
    };
} forEach ("getNumber (_x >> 'BO_basePrice') > 0" configClasses (configFile >> "CfgVehicles"));

// 3. Apply admin runtime overrides.
private _overrides = server getVariable ["BO_priceOverrides", []];
{
    _x params ["_cls", "_price"];
    cost setVariable [_cls, [_price, 0, 0, 0], true];
} forEach _overrides;

private _elapsed = diag_tickTime - _t0;

private _initMsg = format ["Pricing initialized: %1 mod packs, %2 author-tagged items, %3 admin overrides in %4s",
    _packLoaded, _attrLoaded, count _overrides, _elapsed];
BO_LOG_INFO("pricing", _initMsg);

[AUDIT_PRICING,
 format ["Pricing initialized: %1 packs, %2 tagged items, %3 admin overrides", _packLoaded, _attrLoaded, count _overrides],
 [_packLoaded, _attrLoaded, count _overrides],
 "",
 ""
] call BO_fnc_auditServer;
