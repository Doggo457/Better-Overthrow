#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_setPrice
 *
 * Admin runtime price override. Persists across saves via
 * BO_priceOverrides server var. Use sparingly — for cases where the
 * resolver chain produced a bad result and you don't have time to
 * publish a curated pack.
 *
 * Params:
 *   0: STRING - class name
 *   1: SCALAR - new base price
 *   2: SCALAR - optional wood cost (default 0)
 *   3: SCALAR - optional steel cost (default 0)
 *   4: SCALAR - optional plastic cost (default 0)
 */

SERVER_ONLY;

params [
    ["_cls", "", [""]],
    ["_price", 0, [0]],
    ["_wood", 0, [0]],
    ["_steel", 0, [0]],
    ["_plastic", 0, [0]]
];

REQUIRE(_cls isNotEqualTo "", "No class name", nil);
REQUIRE(_price > 0, "Price must be positive", nil);

cost setVariable [_cls, [_price, _wood, _steel, _plastic], true];

// Persist for future saves.
private _overrides = server getVariable ["BO_priceOverrides", []];
private _existingIdx = _overrides findIf { (_x select 0) isEqualTo _cls };
private _entry = [_cls, _price, _wood, _steel, _plastic];
if (_existingIdx >= 0) then {
    _overrides set [_existingIdx, _entry];
} else {
    _overrides pushBack _entry;
};
server setVariable ["BO_priceOverrides", _overrides, true];

[AUDIT_PRICING,
 format ["Admin override: %1 = $%2", _cls, _price],
 [_cls, _price],
 "",
 ""
] call BO_fnc_auditServer;

[] call BO_fnc_requestSave;
