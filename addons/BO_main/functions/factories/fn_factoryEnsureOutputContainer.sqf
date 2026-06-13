#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryEnsureOutputContainer
 *
 * Idempotent: if the factory's BO_outputContainer var points at a
 * live crate, returns it. Otherwise tries to re-bind to a nearby
 * BO_factoryCrate-tagged crate (the one initFactory deferred-spawns
 * 3s after placement; or the one loadGame restored from save). If
 * neither exists, spawns a fresh crate, tags it BO_factoryCrate=true,
 * applies setOwner to the first general, and clears default cargo.
 *
 * Spawn position uses findEmptyPosition with a fallback to a
 * 15m offset perpendicular to the factory's facing.
 *
 * Server-only -- crate creation is server-auth.
 *
 * Params:
 *   0: OBJECT - factory
 *
 * Returns: OBJECT - the output crate (objNull on failure).
 */

SERVER_ONLY_RET(objNull);

params [["_factory", objNull, [objNull]]];
if (isNull _factory) exitWith { objNull };

private _crate = _factory getVariable ["BO_outputContainer", objNull];
if (!isNull _crate && {alive _crate}) exitWith { _crate };

// Try re-binding to an existing nearby BO_factoryCrate. This handles
// the load case (slot-9 restore set BO_factoryCrate=true on the saved
// crate but the factory object var wasn't restored) and the legacy
// case (initFactory's deferred 3s spawn beat us here).
//
// Owner-aware two-pass scan: prevents cluster-rebinds where a newly
// placed factory 3s-deferred crate spawn was rebinding to the FIRST
// nearby factory's crate (the BO_factoryCrate tag has no owner
// identity). Pass 1 matches a crate explicitly bound to THIS factory
// (fresh session / re-init). Pass 2 claims a saved, tagged, NOT-YET-
// CLAIMED crate within a tight radius (owner refs don't survive
// save/load). Radius 25m is well inside the 10-40m findEmptyPosition
// span yet smaller than any sane inter-building spacing, so
// cluster-rebinds cannot occur.
private _factoryPos = getPosATL _factory;
private _existing = objNull;

// Pass 1: a crate explicitly bound to THIS factory.
{
    if ((_x getVariable ["BO_factoryOwner", objNull]) isEqualTo _factory) exitWith {
        _existing = _x;
    };
} forEach (_factoryPos nearObjects [OT_item_CargoContainer, 60]);

// Pass 2: a saved, tagged, unclaimed crate within a tight radius.
if (isNull _existing) then {
    {
        if (_x getVariable ["BO_factoryCrate", false]
            && {isNull (_x getVariable ["BO_factoryOwner", objNull])}) exitWith {
            _existing = _x;
            _x setVariable ["BO_factoryOwner", _factory, true];
        };
    } forEach (_factoryPos nearObjects [OT_item_CargoContainer, 25]);
};

if (!isNull _existing) then {
    _factory setVariable ["BO_outputContainer", _existing, true];
    private _msg = format ["Factory %1 rebound to existing crate", _factory];
    BO_LOG_DEBUG("factory", _msg);
} else {
    private _spot = _factoryPos findEmptyPosition [10, 40, OT_item_CargoContainer];
    if (_spot isEqualTo []) then {
        _spot = _factory getPos [15, (getDir _factory) + 90];
    };
    _crate = OT_item_CargoContainer createVehicle _spot;
    _crate setPosATL _spot;
    _crate setVariable ["BO_factoryCrate", true, true];
    _crate setVariable ["BO_factoryOwner", _factory, true];

    private _generals = server getVariable ["generals", []];
    if (count _generals > 0) then {
        [_crate, _generals select 0] call OT_fnc_setOwner;
    };
    clearWeaponCargoGlobal   _crate;
    clearMagazineCargoGlobal _crate;
    clearItemCargoGlobal     _crate;
    clearBackpackCargoGlobal _crate;

    _factory setVariable ["BO_outputContainer", _crate, true];
    private _msg = format ["Factory %1 spawned new output crate at %2", _factory, _spot];
    BO_LOG_DEBUG("factory", _msg);
    _existing = _crate;
};

_existing
