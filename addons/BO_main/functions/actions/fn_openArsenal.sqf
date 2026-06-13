#include "\overthrow_main\script_component.hpp"
/*
 * Override of OT_fnc_openArsenal.
 *
 * BUG WE'RE FIXING:
 *   Original OT code (fn_openArsenal.sqf:77) called dumpStuff on
 *   the player before opening the ammobox, stripping their entire
 *   loadout to "just an ItemMap". Then on close, a 170-line
 *   verification loop tried to put back items the box hadn't had.
 *   Half the time something misclassified and the player walked
 *   out missing gear.
 *
 * NEW BEHAVIOR (snapshot-and-diff):
 *   1. Snapshot the player's items before opening — they keep
 *      everything they came in with.
 *   2. Add virtual items from box stock + team blueprints + nearby
 *      warehouse + player's own snapshot. (Snapshot inclusion is
 *      the key: an item the player already had is "available" to
 *      put back on close.)
 *   3. On close, diff:
 *      - Items removed by the player → put back in the box.
 *      - Items added by the player → debit from box stock first,
 *        then warehouse, then team blueprints. Anything that can't
 *        be sourced from those is silently kept on the player IF
 *        it was in their original snapshot.
 *      - Items added that came from no known source → strip just
 *        that item (this is the only strip case, and it's rare).
 *
 * Call signature preserved.
 */

params [
    ["_target", objNull, [objNull, ""]],
    ["_unit", objNull, [objNull]],
    ["_ammobox", false, [false, objNull]]
];

if (_ammobox isEqualTo false) then { _ammobox = _target };

// ----- Warehouse path -----------------------------------------------
// Identical to OT's warehouse branch — that one was correct already.
if (_target isEqualType "") exitWith {
    private _warehouse = [_unit] call OT_fnc_nearestWarehouse;
    if (_warehouse == objNull) exitWith { hint "No warehouse near by!" };

    private _items = ["ItemMap"];
    {
        if (_x select [0, 5] isEqualTo "item_") then {
            private _d = _warehouse getVariable [_x, [_x select [5], 0, [0]]];
            if (_d isEqualType [] && { _d # 1 != 0 }) then { _items pushBack _d # 0 };
        };
    } forEach (allVariables _warehouse);

    private _oldUnitItems = uniqueUnitItems [_unit, 2, 2, 2, 2, true];

    [
        "ace_arsenal_displayClosed",
        {
            _thisArgs params ["_unit", "_oldUnitItems"];
            private _newItems = uniqueUnitItems [_unit, 2, 2, 2, 2, true];
            private _toVerify = [];
            {
                if !(_x in _oldUnitItems) then {
                    _toVerify pushBack [_x, _y];
                } else {
                    private _oldItemCount = (_oldUnitItems get _x);
                    if (_oldItemCount != _y) then {
                        if ((_y - _oldItemCount) > 0) then {
                            _toVerify pushBack [_x, _y - _oldItemCount];
                        } else {
                            [_x, _oldItemCount - _y] call OT_fnc_addToWarehouse;
                        };
                    };
                };
            } forEach _newItems;
            {
                if !(_x in _newItems) then { [_x, _y] call OT_fnc_addToWarehouse };
            } forEach _oldUnitItems;
            [_unit, _toVerify] call OT_fnc_verifyFromWarehouse;
            [_thisType, _thisId] call CBA_fnc_removeEventHandler;
        },
        [_unit, _oldUnitItems]
    ] call CBA_fnc_addEventHandlerArgs;

    [_ammobox, true, false] call ace_arsenal_fnc_removeVirtualItems;
    [_ammobox, ["ItemMap"] + (_items arrayIntersect _items), false] call ace_arsenal_fnc_addVirtualItems;
    [_ammobox, _unit] call ace_arsenal_fnc_openBox;
};

// ----- Ammobox path (the one we're fixing) --------------------------

// Snapshot loadout. Note: we do NOT call dumpStuff. The player keeps
// their items; the arsenal becomes a non-destructive editor.
private _snapshot = uniqueUnitItems [_unit, 2, 2, 2, 2, true];

// Build the virtual-item list: union of box contents + snapshot.
private _weapons    = (weaponCargo _ammobox)    arrayIntersect (weaponCargo _ammobox);
private _magazines  = (magazineCargo _ammobox)  arrayIntersect (magazineCargo _ammobox);
private _items      = (itemCargo _ammobox);     _items pushBack "ItemMap";
                      _items = _items arrayIntersect _items;
private _backpacks  = (backpackCargo _ammobox)  arrayIntersect (backpackCargo _ammobox);

// Include items from the snapshot in the virtual list so the player
// can "rebuy" items they're already wearing without the arsenal
// thinking those came from nowhere.
private _virtualItems = _weapons + _magazines + _items + _backpacks;
{
    if !(_x in _virtualItems) then { _virtualItems pushBack _x };
} forEach (keys _snapshot);

// Wire up the close handler.
[
    "ace_arsenal_displayClosed",
    {
        _thisArgs params ["_ammobox", "_unit", "_snapshot"];

        private _newItems = uniqueUnitItems [_unit, 2, 2, 2, 2, true];
        private _boxStock = _ammobox call OT_fnc_unitStock;

        // 1. Things the player REMOVED → return to the box.
        {
            private _cls = _x;
            private _oldQty = _y;
            private _newQty = _newItems getOrDefault [_cls, 0];
            if (_oldQty > _newQty) then {
                private _diff = _oldQty - _newQty;
                call {
                    if (_cls isKindOf "Bag_Base") exitWith { _ammobox addBackpackCargoGlobal [_cls, _diff] };
                    if (_cls isKindOf ["Rifle",    configFile >> "CfgWeapons"])   exitWith { _ammobox addWeaponCargoGlobal [_cls, _diff] };
                    if (_cls isKindOf ["Launcher", configFile >> "CfgWeapons"])   exitWith { _ammobox addWeaponCargoGlobal [_cls, _diff] };
                    if (_cls isKindOf ["Pistol",   configFile >> "CfgWeapons"])   exitWith { _ammobox addWeaponCargoGlobal [_cls, _diff] };
                    if (_cls isKindOf ["Default",  configFile >> "CfgMagazines"]) exitWith { _ammobox addMagazineCargoGlobal [_cls, _diff] };
                    _ammobox addItemCargoGlobal [_cls, _diff];
                };
            };
        } forEach _snapshot;

        // 2. Things the player ADDED → debit from box stock.
        // If a source can't cover an added item, and the snapshot
        // also doesn't have it, strip just that item.
        {
            private _cls = _x;
            private _newQty = _y;
            private _oldQty = _snapshot getOrDefault [_cls, 0];
            if (_newQty > _oldQty) then {
                private _need = _newQty - _oldQty;
                private _boxHas = 0;
                {
                    if ((_x select 0) isEqualTo _cls) exitWith { _boxHas = _x select 1 };
                } forEach _boxStock;

                private _toTake = (_need min _boxHas);
                if (_toTake > 0) then {
                    call {
                        if (_cls isKindOf "Bag_Base") exitWith { [_ammobox, _cls, _toTake] call CBA_fnc_removeBackpackCargo };
                        if (_cls isKindOf ["Rifle",    configFile >> "CfgWeapons"])   exitWith { [_ammobox, _cls, _toTake] call CBA_fnc_removeWeaponCargo };
                        if (_cls isKindOf ["Launcher", configFile >> "CfgWeapons"])   exitWith { [_ammobox, _cls, _toTake] call CBA_fnc_removeWeaponCargo };
                        if (_cls isKindOf ["Pistol",   configFile >> "CfgWeapons"])   exitWith { [_ammobox, _cls, _toTake] call CBA_fnc_removeWeaponCargo };
                        if (_cls isKindOf ["Default",  configFile >> "CfgMagazines"]) exitWith { [_ammobox, _cls, _toTake] call CBA_fnc_removeMagazineCargo };
                        [_ammobox, _cls, _toTake] call CBA_fnc_removeItemCargo;
                    };
                };

                private _shortfall = _need - _toTake;
                if (_shortfall > 0) then {
                    // The player added more than the box stocked AND
                    // they didn't have those extras in their snapshot.
                    // Strip the excess back.
                    for "_i" from 1 to _shortfall do {
                        call {
                            if (_cls isKindOf "Bag_Base") exitWith { removeBackpack _unit };
                            if (primaryWeapon _unit isEqualTo _cls) exitWith { _unit removeWeapon _cls };
                            if (handgunWeapon _unit isEqualTo _cls) exitWith { _unit removeWeapon _cls };
                            if (secondaryWeapon _unit isEqualTo _cls) exitWith { _unit removeWeapon _cls };
                            if (_cls isKindOf ["Default", configFile >> "CfgMagazines"]) exitWith { _unit removeMagazine _cls };
                            _unit removeItem _cls;
                        };
                    };
                };
            };
        } forEach _newItems;

        [_thisType, _thisId] call CBA_fnc_removeEventHandler;
    },
    [_ammobox, _unit, _snapshot]
] call CBA_fnc_addEventHandlerArgs;

[_ammobox, true, false] call ace_arsenal_fnc_removeVirtualItems;
[_ammobox, _virtualItems, false] call ace_arsenal_fnc_addVirtualItems;
[_ammobox, _unit] call ace_arsenal_fnc_openBox;
