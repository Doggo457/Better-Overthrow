#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_lookupFactionAverage
 *
 * For a given weapon, find which factions use it (via the
 * `spawner var "facweapons%1"` arrays built by OT_fnc_initVar) and
 * return the average price of similarly-typed weapons in those
 * factions.
 *
 * If the item isn't a weapon or no faction usage data exists, returns nil.
 *
 * Params:
 *   0: STRING - class name
 *
 * Returns: ARRAY [base, wood, steel, plastic] or nil.
 */

params [["_cls", "", [""]]];

if (_cls isEqualTo "") exitWith { nil };

// Find factions that include this weapon.
private _factionsHere = [];
{
    private _faction = _x select 0;
    private _facWeapons = spawner getVariable [format ["facweapons%1", _faction], []];
    if (_cls in _facWeapons) then { _factionsHere pushBack _faction };
} forEach OT_allFactions;

if (_factionsHere isEqualTo []) exitWith { nil };

// Determine this weapon's category (same approach OT uses).
private _wCfg = configFile >> "CfgWeapons" >> _cls;
if (!isClass _wCfg) exitWith { nil };

private _myType = ([_cls] call BIS_fnc_itemType) select 1;

// Aggregate same-type weapons across the factions and average their
// known prices.
private _sum = 0;
private _count = 0;
{
    private _facWeapons = spawner getVariable [format ["facweapons%1", _x], []];
    {
        private _otherCls = _x;
        if (_otherCls isNotEqualTo _cls && {isClass (configFile >> "CfgWeapons" >> _otherCls)}) then {
            private _otherType = ([_otherCls] call BIS_fnc_itemType) select 1;
            if (_otherType isEqualTo _myType) then {
                private _existing = cost getVariable [_otherCls, nil];
                if (!isNil "_existing") then {
                    _sum = _sum + (_existing select 0);
                    _count = _count + 1;
                };
            };
        };
    } forEach _facWeapons;
} forEach _factionsHere;

if (_count isEqualTo 0) exitWith { nil };

private _avg = round (_sum / _count);
[_avg, 0, 2, 0] // weapons usually have light steel cost
