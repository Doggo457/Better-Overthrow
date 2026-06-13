#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initFactory
 *
 * Called when a Factory buildable is placed AND when a saved
 * factory is rehydrated by loadGame (slot-6 OT_init replay).
 *
 * MULTI-FACTORY MODEL: state lives on the factory object, not on
 * missionNamespace globals. Each placed factory holds its own
 * BO_queue / BO_producing / BO_producetime / BO_outputContainer
 * etc. The server-side BO_buildFactories registry (populated by
 * BO_fnc_registerFactory) drives the per-frame tick.
 *
 * This function is idempotent w.r.t. per-object vars: it only
 * defaults a var if it's nil, so a freshly loaded factory that
 * came back with a half-built queue keeps its state.
 *
 * Legacy compat: the FIRST factory placed (and only the first)
 * also bumps OT_factoryPos / OT_factoryVehicleSpawn /
 * OT_factoryVehicleDir so any leftover single-factory code paths
 * (fn_canPlace, fn_manageArea, fn_replaceStructureCrate) still
 * find a sensible anchor. Subsequent placements DO NOT relocate
 * the globals -- they get their own per-object state, registered
 * via the registry.
 *
 * The "Factory" entry is pushed into GEURowned the first time only
 * (idempotent check).
 *
 * Called via `[_pos, _veh] spawn BO_fnc_initFactory` from
 * fn_initBuilding.
 */

if (!isServer) exitWith {};

params [
    ["_pos", [0,0,0], [[]]],
    ["_factory", objNull, [objNull]]
];
if (isNull _factory) exitWith {};

// Legacy globals (OT_factoryPos / OT_factoryVehicleSpawn /
// OT_factoryVehicleDir) are NOT touched here in the multi-factory
// model. They retain their map-baked values from data/economy.sqf
// so leftover OT_factoryPos-based code (canPlace fallback, the
// starter marker in initEconomyLoad, manageArea fallback) continues
// to anchor at the original starter site. Each placed factory
// carries its own state on the object instead.

// GEURowned "Factory" flag -- idempotent push. The wage tick in
// GUERLoop and the marker color logic in initEconomyLoad still
// gate off this flag.
private _owned = server getVariable ["GEURowned", []];
if !("Factory" in _owned) then {
    _owned pushBack "Factory";
    server setVariable ["GEURowned", _owned, true];
};

// Per-object state defaults. Only set if nil so a loaded factory's
// restored vars survive this rehydrate path. Use `isNil` for
// missing-variable detection (default-arg getVariable would
// substitute the default and lie about presence).
if (isNil { _factory getVariable "BO_queue" })           then { _factory setVariable ["BO_queue", [], true] };
if (isNil { _factory getVariable "BO_producing" })       then { _factory setVariable ["BO_producing", "", true] };
if (isNil { _factory getVariable "BO_producetime" })     then { _factory setVariable ["BO_producetime", 0, true] };
if (isNil { _factory getVariable "BO_factoryEnabled" })  then { _factory setVariable ["BO_factoryEnabled", true, true] };
if (isNil { _factory getVariable "BO_factoryName" })     then { _factory setVariable ["BO_factoryName", "", true] };

// Mark for save even if unowned -- player-placed factories don't get
// an OT owner via this pipeline (only the input crate does), so
// without this flag OT_fnc_saveGame's filter would drop the factory
// from persistence and BO_queue / BO_producing / BO_producetime
// would never round-trip. Slot 10 in fn_saveGame carries the actual
// per-factory state payload.
_factory setVariable ["OT_forceSaveUnowned", true, true];
// BO_outputContainer is intentionally left untouched -- the
// 3s-deferred ensure-call below populates it AFTER the load
// vehicle loop has restored any saved BO_factoryCrate.

// Defer the output-crate spawn 3s. Two reasons:
//   1. On load, vehicles are restored sequentially in fn_loadGame;
//      a factory's OT_init replay (which lands us here) may run
//      before its saved crate has been re-spawned. Looking
//      immediately would not see the crate and we'd spawn a
//      duplicate. Waiting lets the vehicle loop drain.
//   2. On fresh placement, the player just dropped the factory and
//      doesn't see a crate appear inside their build placement
//      effect -- the brief delay is barely noticeable.
[{
    params ["_factory"];
    if (isNull _factory) exitWith {};
    [_factory] call BO_fnc_factoryEnsureOutputContainer;
}, [_factory], 3] call CBA_fnc_waitAndExecute;

// Register with the multi-factory tick loop. Idempotent on the
// registry side. The PFH iterates this list every interval.
[_factory] call BO_fnc_registerFactory;

[AUDIT_ADMIN, "Factory placed/relocated", [getPosATL _factory, count (server getVariable ["BO_buildFactories", []])], "", ""] call BO_fnc_auditServer;

private _msg = format ["Factory operational at %1", mapGridPosition _factory];
_msg remoteExec ["OT_fnc_notifyGood", 0, false];
