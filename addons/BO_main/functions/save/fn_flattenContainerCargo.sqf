#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_flattenContainerCargo
 *
 * Strip-and-unpack snapshot of a container's cargo for the save
 * system. Returns a consolidated [[cls, count], ...] list in the
 * same shape OT_fnc_unitStock produces (so the existing load code
 * needs no changes), but with full fidelity:
 *
 *   - Weapons in cargo:        bare classname + each attachment
 *                              (muzzle/flash/optic/underbarrel)
 *                              + each pre-loaded magazine
 *   - Weapons inside bags:     same treatment (OT_fnc_unitStock
 *                              loses these attachments)
 *   - Bags in cargo:           the bag classname (empty) + every
 *                              piece of cargo from inside the bag
 *                              gets flattened to the top level
 *   - Items / magazines:       passed through as-is
 *
 * On reload the existing OT vehicle-load branch dispatches each
 * entry by isKindOf to addWeaponCargoGlobal / addMagazineCargoGlobal
 * / addBackpackCargoGlobal / addItemCargoGlobal, so a flattened
 * snapshot reconstructs as: bare weapons + loose attachments +
 * empty bags + loose contents. Matches the dispatch-time strip
 * model so save/load and logistics behave consistently.
 *
 * Partial-ammo magazines lose their partial count (all mags arrive
 * full). Acceptable per the user-stated preference for scalable
 * loose storage.
 *
 * Params:
 *   0: OBJECT - the container
 *
 * Returns:
 *   [[cls, count], ...] consolidated. Empty array if the container
 *   has no cargo.
 */

params [["_container", objNull, [objNull]]];
if (isNull _container) exitWith { [] };

// Inline weapon-config flattener: takes a weaponsItemsCargo entry
// and pushes the bare weapon + attachments + loaded mags into the
// shared flat list.
private _expandWeapon = {
    params ["_wpn", "_flat"];
    private _w = _wpn select 0;
    if (_w isNotEqualTo "") then {
        _flat pushBack (_w call BIS_fnc_baseWeapon);
    };
    {
        if (_x isEqualType "" && { _x isNotEqualTo "" }) then {
            _flat pushBack _x;
        };
    } forEach [_wpn select 1, _wpn select 2, _wpn select 3, _wpn select 6];
    {
        if (_x isEqualType [] && { (count _x) > 0 && { (_x select 0) isNotEqualTo "" } }) then {
            _flat pushBack (_x select 0);
        };
    } forEach [_wpn select 4, _wpn select 5];
};

private _flat = [];

// Items, magazines, backpacks directly in the crate's cargo.
_flat append (itemCargo     _container);
_flat append (magazineCargo _container);
_flat append (backpackCargo _container);

// Weapons in the crate's cargo: strip attachments + loaded mags.
{ [_x, _flat] call _expandWeapon } forEach (weaponsItemsCargo _container);

// Walk inner containers (bags, vests, uniforms) and flatten their
// contents to the top level. The container objects themselves are
// already covered by backpackCargo above (for bags); we just need
// their cargo.
{
    _x params ["_innerCls", "_innerObj"];
    if (isNull _innerObj) then { continue };

    _flat append (itemCargo     _innerObj);
    _flat append (magazineCargo _innerObj);
    _flat append (backpackCargo _innerObj);
    { [_x, _flat] call _expandWeapon } forEach (weaponsItemsCargo _innerObj);
} forEach (everyContainer _container);

// Drop empties, apply OT's no-copy-mag exclusion list, consolidate
// to [[cls, count], ...].
_flat = _flat - [""];
if (!isNil "OT_noCopyMags") then { _flat = _flat - OT_noCopyMags };

_flat call BIS_fnc_consolidateArray
