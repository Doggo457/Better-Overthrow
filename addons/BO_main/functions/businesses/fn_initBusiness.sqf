#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initBusiness
 *
 * Shared core called by the 6 type-specific init wrappers
 * (BO_fnc_initLumberyard etc) when a BO production business
 * is placed AND when a saved business is rehydrated by loadGame
 * (slot-6 OT_init replay of the type-specific wrapper).
 *
 * Mirrors fn_initFactory's shape:
 *   - per-object state lives on the building (BO_businessType,
 *     BO_businessEnabled, BO_businessLastHour)
 *   - the building is registered in server var "BO_buildBusinesses"
 *     which the per-frame tick walks
 *   - an I/O cargo container spawns adjacent (deferred 3s so it
 *     races cleanly with the load vehicle loop)
 *   - the business gets OT_forceSaveUnowned so save can pick it up
 *
 * Idempotent on per-object vars: nil-checks let a rehydrated
 * business keep its restored type/enabled/lastHour from slot 11.
 *
 * Params:
 *   0: ARRAY  - position (unused, kept for signature parity with
 *               OT init function shape)
 *   1: OBJECT - the building (business)
 *   2: STRING - business type display name (key into BO_businessTypes)
 */

if (!isServer) exitWith {};

params [
    ["_pos", [0,0,0], [[]]],
    ["_business", objNull, [objNull]],
    ["_type", "", [""]]
];
if (isNull _business) exitWith {};
if (_type isEqualTo "") exitWith {
    BO_LOG_WARN("business","initBusiness called with empty type -- ignoring");
};
if (isNil "BO_businessTypes" || {!(_type in BO_businessTypes)}) exitWith {
    private _msg = format ["initBusiness: unknown type '%1' (no spec in BO_businessTypes)", _type];
    BO_LOG_WARN("business", _msg);
};

// Per-object state defaults. Only set if nil so a loaded business's
// restored vars survive this rehydrate path.
if (isNil { _business getVariable "BO_businessType" })     then { _business setVariable ["BO_businessType", _type, true] };
if (isNil { _business getVariable "BO_businessEnabled" })  then { _business setVariable ["BO_businessEnabled", true, true] };
if (isNil { _business getVariable "BO_businessLastHour" }) then { _business setVariable ["BO_businessLastHour", -1, true] };

// Mark for save even if unowned -- player-placed businesses don't
// get an OT owner on placement (only the I/O crate does), so without
// this flag OT_fnc_saveGame's filter would drop the building from
// persistence and the per-object state would never round-trip.
// Slot 11 in fn_saveGame carries the per-business state payload.
_business setVariable ["OT_forceSaveUnowned", true, true];

// Defer the I/O crate spawn 3s. Same reasoning as factories:
//   1. On load, vehicles are restored sequentially in fn_loadGame;
//      the slot-6 OT_init replay may run before the saved crate has
//      been re-spawned. Waiting lets the vehicle loop drain so we
//      can rebind to it rather than spawning a duplicate.
//   2. On fresh placement, the brief delay is barely noticeable.
[{
    params ["_business"];
    if (isNull _business) exitWith {};
    [_business] call BO_fnc_businessEnsureCrate;
}, [_business], 3] call CBA_fnc_waitAndExecute;

// Register with the multi-business tick loop. Idempotent on the
// registry side. The PFH iterates this list every interval.
[_business] call BO_fnc_registerBusiness;

// Register a virtualization spawner so OT spawns exactly ONE worker
// NPC at this business when a player enters spawn distance, and
// despawns the worker when the player leaves. The wage tick still
// charges the full _employees count -- the rest stay virtual (no
// AI budget cost). Idempotent: skip if a spawner was already
// registered for this business in this session.
if (isNil { _business getVariable "BO_businessSpawnerId" }) then {
    private _spawnerNum = [getPosATL _business, BO_fnc_spawnBusinessWorker, [_business, _type]] call OT_fnc_registerSpawner;
    _business setVariable ["BO_businessSpawnerId", format ["spawn%1", _spawnerNum], true];
};

private _registry = server getVariable ["BO_buildBusinesses", []];
[AUDIT_ADMIN, format ["%1 placed/relocated", _type], [getPosATL _business, count _registry], "", ""] call BO_fnc_auditServer;

private _msg = format ["%1 operational at %2", _type, mapGridPosition _business];
_msg remoteExec ["OT_fnc_notifyGood", 0, false];
