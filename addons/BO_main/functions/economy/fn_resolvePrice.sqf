#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_resolvePrice
 *
 * Authoritative price lookup for a class name. The layered resolver
 * runs in this order, taking the first match:
 *
 *   1. cost namespace already has a value (set by OT, BO mod pack,
 *      BO_basePrice attribute, or admin override)
 *   2. magazine-compatibility equivalent (weapon shares mag with a
 *      known-priced weapon → use that price ± 0%)
 *   3. faction average for the same weapon type
 *   4. category-heuristic with clamps
 *
 * Use this whenever code needs a definitive price and the cost
 * namespace might not yet contain the class. Most OT pathways still
 * read `cost getVariable _cls` directly — those are unaffected. This
 * function is for hot paths that explicitly want our resolver.
 *
 * Params:
 *   0: STRING - class name
 *
 * Returns: ARRAY [base, wood, steel, plastic].
 */

params [["_cls", "", [""]]];

if (_cls isEqualTo "") exitWith { [10, 0, 0, 0] };

// Step 1: cost namespace.
private _existing = cost getVariable [_cls, nil];
if (!isNil "_existing") exitWith { _existing };

// Step 2: magazine-compatibility lookup (weapons only).
if (isClass (configFile >> "CfgWeapons" >> _cls)) then {
    private _eq = [_cls] call BO_fnc_lookupMagazineEquivalent;
    if (!isNil "_eq") exitWith {
        cost setVariable [_cls, _eq, true];
        private _resMsg = format ["Resolved %1 by magazine compatibility", _cls];
        BO_LOG_DEBUG("pricing", _resMsg);
        _eq
    };
};

// Step 3: faction average.
private _fa = [_cls] call BO_fnc_lookupFactionAverage;
if (!isNil "_fa") exitWith {
    cost setVariable [_cls, _fa, true];
    private _resMsg = format ["Resolved %1 by faction average", _cls];
    BO_LOG_DEBUG("pricing", _resMsg);
    _fa
};

// Step 4: heuristic with clamps.
private _h = [_cls] call BO_fnc_priceFallbackHeuristic;
cost setVariable [_cls, _h, true];

// Log this as a "fell through" since it indicates the mod might benefit
// from a curated pack.
[AUDIT_PRICING,
 format ["Item '%1' fell to heuristic fallback: %2", _cls, _h],
 _h,
 "",
 ""
] call BO_fnc_auditServer;

_h
