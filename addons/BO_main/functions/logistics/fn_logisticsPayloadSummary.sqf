#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsPayloadSummary
 *
 * Reduce a delivery payload to a short `[_totalUnits, _displayText]`
 * pair for the Active Deliveries listbox.
 *
 * Payload shapes the function handles:
 *
 *   Typed (current):
 *     [_weapons, _magazines, _items, _backpacks]
 *     _weapons = [[wpn, muzzle, flash, optic, [pmag, ammo],
 *                  [smag, sammo], underbarrel], ...]
 *     _magazines / _items / _backpacks = [[cls, qty], ...]
 *
 *   Typed legacy (post-typing, pre-attachment-fix):
 *     [_weapons, _magazines, _items, _backpacks]
 *     _weapons = [[cls, qty], ...] (bare classnames)
 *     others same as above.
 *
 *   Flat legacy (oldest):
 *     [[cls, qty], ...] mixed types.
 *
 * Detection: a 4-element top-level array whose first element is
 * itself an array (or empty) is typed. Inside the weapons bucket,
 * a 7+ element entry whose second element is a string is the
 * with-attachments form; a 2-element entry whose second is a
 * number is legacy bare-weapon.
 */

params [["_payload", [], [[]]]];

private _w = [];
private _m = [];
private _i = [];
private _b = [];

private _isTyped = (count _payload isEqualTo 4)
    && {
        private _first = _payload select 0;
        (_first isEqualType []) && { (_first isEqualTo []) || { (_first select 0) isEqualType [] } }
    };

if (_isTyped) then {
    _w = _payload select 0;
    _m = _payload select 1;
    _i = _payload select 2;
    _b = _payload select 3;
} else {
    _i = _payload;
};

// Weapons count: with-attachments = 1 per entry; legacy bare = qty
// from the [cls, qty] pair.
private _weaponUnits = 0;
private _firstWeaponCls = "";
{
    if (count _x >= 7 && {(_x select 1) isEqualType ""}) then {
        _weaponUnits = _weaponUnits + 1;
        if (_firstWeaponCls isEqualTo "") then { _firstWeaponCls = _x select 0 };
    } else {
        _weaponUnits = _weaponUnits + (_x select 1);
        if (_firstWeaponCls isEqualTo "") then { _firstWeaponCls = _x select 0 };
    };
} forEach _w;

private _otherEntries = _m + _i + _b;
private _otherUnits = 0;
{ _otherUnits = _otherUnits + (_x select 1) } forEach _otherEntries;

private _total = _weaponUnits + _otherUnits;
private _bucketCount = (count _w) + (count _otherEntries);

private _displayText = if (_total isEqualTo 0) then {
    "(empty)"
} else {
    private _firstCls = if (_firstWeaponCls isNotEqualTo "") then {
        _firstWeaponCls
    } else {
        (_otherEntries select 0) select 0
    };
    if (_bucketCount > 1) then {
        format ["%1 x %2 (+%3 more)", _total, _firstCls, _bucketCount - 1]
    } else {
        format ["%1 x %2", _total, _firstCls]
    };
};

[_total, _displayText]
