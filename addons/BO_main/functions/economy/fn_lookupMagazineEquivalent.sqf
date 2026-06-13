#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_lookupMagazineEquivalent
 *
 * Find a vanilla/known-priced weapon that shares magazines with the
 * given weapon, and return its price. Magazine compatibility is the
 * strongest similarity signal in Arma: weapons sharing mags are
 * almost always in the same tier.
 *
 * Params:
 *   0: STRING - weapon class name
 *
 * Returns: ARRAY [base, wood, steel, plastic] or nil if no match.
 */

params [["_cls", "", [""]]];

if (_cls isEqualTo "") exitWith { nil };
private _wCfg = configFile >> "CfgWeapons" >> _cls;
if (!isClass _wCfg) exitWith { nil };

private _myMags = getArray (_wCfg >> "magazines");
if (_myMags isEqualTo []) exitWith { nil };

// Scan known-priced weapons for any that share a magazine.
private _allWeapons = "
    getNumber (_x >> 'scope') isEqualTo 2 &&
    {getNumber (_x >> 'type') in [1, 2, 4]}
" configClasses (configFile >> "CfgWeapons");

private _bestMatch = nil;
{
    private _otherCls = configName _x;
    if (_otherCls isNotEqualTo _cls) then {
        private _existing = cost getVariable [_otherCls, nil];
        if (!isNil "_existing") then {
            private _otherMags = getArray (_x >> "magazines");
            // Set-intersection: any shared mag class?
            private _shared = false;
            {
                if (_x in _otherMags) exitWith { _shared = true };
            } forEach _myMags;
            if (_shared && {isNil "_bestMatch" || {(_existing select 0) > (_bestMatch select 0)}}) then {
                _bestMatch = _existing;
            };
        };
    };
} forEach _allWeapons;

_bestMatch
