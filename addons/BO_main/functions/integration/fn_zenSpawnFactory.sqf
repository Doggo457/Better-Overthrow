#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSpawnFactory
 *
 * Zen module: place a fully-initialized Factory at the module position.
 * Wires it into BO_buildFactories via BO_fnc_initFactory so the
 * standard multi-factory tick produces from it. The I/O crate
 * spawns 3s after placement (same as a normal build).
 *
 * Params (Zen module signature):
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic (to be deleted)
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _model = if (!isNil "OT_factory") then { OT_factory } else { "Land_dp_smallFactory_F" };
private _factory = createVehicle [_model, _position, [], 0, "NONE"];
_factory setPosATL _position;
_factory setVariable ["OT_init", "BO_fnc_initFactory", true];
[_factory, getPos _factory, "BO_fnc_initFactory"] call OT_fnc_initBuilding;

private _msg = format ["Zeus spawned Factory at %1", mapGridPosition _factory];
_msg call OT_fnc_notifyGood;
[AUDIT_ADMIN, _msg, [_position], "", ""] call BO_fnc_auditServer;
