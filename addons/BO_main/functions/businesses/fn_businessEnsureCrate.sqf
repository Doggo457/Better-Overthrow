#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_businessEnsureCrate
 *
 * Idempotent: if the business's BO_businessIOCrate var points at a
 * live crate, returns it. Otherwise tries to re-bind to a nearby
 * BO_businessCrate-tagged crate (the one initBusiness deferred-spawns
 * 3s after placement; or the one loadGame restored from save). If
 * neither exists, spawns a fresh crate, tags it BO_businessCrate=true,
 * applies setOwner to the first general, and clears default cargo.
 *
 * Server-only -- crate creation is server-auth.
 *
 * Params:
 *   0: OBJECT - business building
 *
 * Returns: OBJECT - the I/O crate (objNull on failure).
 */

if (!isServer) exitWith { objNull };

params [["_business", objNull, [objNull]]];
if (isNull _business) exitWith { objNull };

private _crate = _business getVariable ["BO_businessIOCrate", objNull];
if (!isNull _crate && {alive _crate}) exitWith { _crate };

// Try re-binding to an existing nearby BO_businessCrate. Handles the
// load case (slot-11 restore set BO_businessCrate=true on the saved
// crate but the building's object-var BO_businessIOCrate wasn't
// restored -- object refs don't survive a save/load round trip) and
// the legacy case (initBusiness's deferred 3s spawn beat us here).
//
// Owner-aware two-pass scan: prevents cluster-rebinds where a newly
// placed business 3s-deferred crate spawn was rebinding to the FIRST
// nearby business's crate (the BO_businessCrate tag has no owner
// identity). Pass 1 matches a crate explicitly bound to THIS business
// (fresh session / re-init). Pass 2 claims a saved, tagged, NOT-YET-
// CLAIMED crate within a tight radius (owner refs don't survive
// save/load). Radius 25m is well inside the 10-40m findEmptyPosition
// span yet smaller than any sane inter-building spacing, so
// cluster-rebinds cannot occur.
private _businessPos = getPosATL _business;
private _existing = objNull;

// Pass 1: a crate explicitly bound to THIS business.
{
    if ((_x getVariable ["BO_businessOwner", objNull]) isEqualTo _business) exitWith {
        _existing = _x;
    };
} forEach (_businessPos nearObjects [OT_item_CargoContainer, 60]);

// Pass 2: a saved, tagged, unclaimed crate within a tight radius.
if (isNull _existing) then {
    {
        if (_x getVariable ["BO_businessCrate", false]
            && {isNull (_x getVariable ["BO_businessOwner", objNull])}) exitWith {
            _existing = _x;
            _x setVariable ["BO_businessOwner", _business, true];
        };
    } forEach (_businessPos nearObjects [OT_item_CargoContainer, 25]);
};

if (!isNull _existing) then {
    _business setVariable ["BO_businessIOCrate", _existing, true];
    private _msg = format ["Business %1 rebound to existing crate", _business];
    BO_LOG_DEBUG("business", _msg);
} else {
    private _spot = _businessPos findEmptyPosition [10, 40, OT_item_CargoContainer];
    if (_spot isEqualTo []) then {
        _spot = _business getPos [15, (getDir _business) + 90];
    };
    _crate = OT_item_CargoContainer createVehicle _spot;
    _crate setPosATL _spot;
    _crate setVariable ["BO_businessCrate", true, true];
    _crate setVariable ["BO_businessOwner", _business, true];

    private _generals = server getVariable ["generals", []];
    if (count _generals > 0) then {
        [_crate, _generals select 0] call OT_fnc_setOwner;
    };
    clearWeaponCargoGlobal   _crate;
    clearMagazineCargoGlobal _crate;
    clearItemCargoGlobal     _crate;
    clearBackpackCargoGlobal _crate;

    _business setVariable ["BO_businessIOCrate", _crate, true];
    private _msg = format ["Business %1 spawned new I/O crate at %2", _business, _spot];
    BO_LOG_DEBUG("business", _msg);
    _existing = _crate;
};

_existing
