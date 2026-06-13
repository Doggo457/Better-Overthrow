#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_replaceStructureCrate
 *
 * Spawn a new input crate at a clear spot near a structure that
 * requires one, transferring inventory from the existing crate if
 * it's still alive, then delete the old crate.
 *
 * Currently the only crate-requiring structure is the Factory; the
 * function is structured around a structure key so additional cases
 * (workshop input box, etc.) can be added by extending the switch.
 *
 * Server-auth: client calls
 *   [_structureKey] remoteExec ["BO_fnc_replaceStructureCrate", 2, false];
 *
 * Params:
 *   0: STRING - structure key, e.g. "Factory"
 *
 * Behaviour:
 *   - Resolves the structure's anchor position (Factory -> OT_factoryPos).
 *   - Finds the nearest existing crate to that anchor; if it's a BO
 *     factory crate (or unowned) we transfer its cargo to the new one.
 *   - findEmptyPosition picks a clear 10-40m radius; if it returns
 *     empty we fall back to a fixed 15m offset perpendicular to the
 *     building's direction.
 *   - The new crate gets the same setOwner + BO_factoryCrate tag so
 *     the existing GUERLoop nearestObject lookup keeps working.
 *   - Audit + notify, both online players.
 */

if (!isServer) exitWith {
    _this remoteExec ["BO_fnc_replaceStructureCrate", 2, false];
};

params [
    ["_key", "Factory", [""]],
    ["_targetFactory", objNull, [objNull]]
];

private _anchor = [];
private _anchorObj = objNull;

switch (_key) do {
    case "Factory": {
        // Multi-factory: caller passes the specific factory object
        // (set from OT_interactingWith in the Y-menu Replace Crate
        // button). If absent (legacy callers), fall back to the
        // starter site's globals.
        if (!isNull _targetFactory && {(typeOf _targetFactory) isEqualTo OT_factory}) then {
            _anchorObj = _targetFactory;
            _anchor = getPosATL _anchorObj;
        } else {
            if (isNil "OT_factoryPos") exitWith {};
            _anchor = OT_factoryPos;
            _anchorObj = _anchor nearestObject OT_factory;
        };
    };
};

if (_anchor isEqualTo []) exitWith {
    private _warnMsg = format ["replaceStructureCrate: unknown structure key '%1'", _key];
    BO_LOG_WARN("admin", _warnMsg);
};

// Find every crate near the anchor. We snapshot cargo from the
// BO-tagged crate (the real factory input crate) but delete EVERY
// crate in the radius -- including untagged duplicates left over
// from previous save/load duplicate bugs -- so the new crate is
// the only one standing afterwards.
private _allCrates = _anchor nearObjects [OT_item_CargoContainer, 100];

private _primary = objNull;
{
    if (_x getVariable ["BO_factoryCrate", false]) exitWith {
        _primary = _x;
    };
} forEach _allCrates;
if (isNull _primary && (count _allCrates > 0)) then {
    _primary = _allCrates select 0;
};

// Snapshot the primary crate's cargo (the one we treat as canonical).
// Duplicates are NOT merged -- their cargo would just confuse the
// output. The user gets one clean crate with the primary's contents.
private _wpns = [[], []];
private _mags = [[], []];
private _itms = [[], []];
private _bags = [[], []];
if (!isNull _primary && {alive _primary}) then {
    _wpns = getWeaponCargo   _primary;
    _mags = getMagazineCargo _primary;
    _itms = getItemCargo     _primary;
    _bags = getBackpackCargo _primary;
};

// Find a clear position. Try findEmptyPosition first, fall back to
// 15m perpendicular to building direction if the search comes back
// empty (very built-up area or props blocking nearby).
private _spot = _anchor findEmptyPosition [10, 40, OT_item_CargoContainer];
if (_spot isEqualTo []) then {
    private _dir = if (!isNull _anchorObj) then { (getDir _anchorObj) + 90 } else { random 360 };
    _spot = _anchor getPos [15, _dir];
};

// Delete EVERY crate in range BEFORE spawning the new one. This
// guarantees no orphan duplicates linger after the operation and
// closes the window where the new crate could inherit default
// editor cargo from a live old crate it overlapped with.
{ deleteVehicle _x } forEach _allCrates;

private _newCrate = OT_item_CargoContainer createVehicle _spot;
_newCrate setPosATL _spot;
_newCrate setVariable ["BO_factoryCrate", true, true];

// Multi-factory: rebind the target factory's BO_outputContainer to
// the new crate so the production tick + ensure-helper find it.
if (!isNull _anchorObj && {(typeOf _anchorObj) isEqualTo OT_factory}) then {
    _anchorObj setVariable ["BO_outputContainer", _newCrate, true];
    // Owner-back-reference so future replace cycles + save/load can
    // walk crates and re-bind by reading BO_factoryOwner. Mirrors the
    // same write at fn_buyBusinessServer.sqf so both creation paths
    // produce a symmetrically-tagged crate.
    _newCrate setVariable ["BO_factoryOwner", _anchorObj, true];
};

// Re-establish OT ownership so it survives despawn cleanup.
private _generals = server getVariable ["generals", []];
if (count _generals > 0) then {
    [_newCrate, _generals select 0] call OT_fnc_setOwner;
};

// Strip the new crate's default cargo (B_Slingload_01_Cargo_F ships
// empty in vanilla, but mods or scenarios may bake some default in).
clearWeaponCargoGlobal   _newCrate;
clearMagazineCargoGlobal _newCrate;
clearItemCargoGlobal     _newCrate;
clearBackpackCargoGlobal _newCrate;

// Restore the snapshot. Use the *Global variants so the cargo is
// visible to every client, not just the server.
private _transferred = 0;
{
    private _qty = (_wpns select 1) select _forEachIndex;
    _newCrate addWeaponCargoGlobal [_x, _qty];
    _transferred = _transferred + _qty;
} forEach (_wpns select 0);

{
    private _qty = (_mags select 1) select _forEachIndex;
    _newCrate addMagazineCargoGlobal [_x, _qty];
    _transferred = _transferred + _qty;
} forEach (_mags select 0);

{
    private _qty = (_itms select 1) select _forEachIndex;
    _newCrate addItemCargoGlobal [_x, _qty];
    _transferred = _transferred + _qty;
} forEach (_itms select 0);

{
    private _qty = (_bags select 1) select _forEachIndex;
    _newCrate addBackpackCargoGlobal [_x, _qty];
    _transferred = _transferred + _qty;
} forEach (_bags select 0);

private _m = format ["%1 crate replaced (transferred %2 items)", _key, _transferred];
[AUDIT_ADMIN, _m, [_key, _transferred], "", ""] call BO_fnc_auditServer;

private _note = format ["%1 crate replaced -- %2 items moved over", _key, _transferred];
_note remoteExec ["OT_fnc_notifyGood", 0, false];
