#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_buyBusinessServer
 *
 * Server-authoritative purchase of a Business or the Factory by the
 * resistance. Performs the atomic read-check-debit-write sequence that
 * the original OT fn_buyBusiness did on the client, so concurrent buys
 * from multiple generals cannot race the GEURowned RMW or double-spend
 * resistance funds. Also fixes the bug where the per-business "employ"
 * counter was set without broadcast=true, so the server-side
 * spawnBusinessEmployees / GUERLoop saw 0 and never spawned the
 * initial workers on dedicated MP.
 *
 * Intended call site (from fn_buyBusiness.sqf on the client):
 *   [_name, _pos, _generalUid, _isFactory] remoteExec
 *       ["BO_fnc_buyBusinessServer", 2, false];
 *
 * Params:
 *   0: STRING - business marker name (or "Factory")
 *   1: ARRAY  - position to reset spawn at
 *   2: STRING - UID of the buying player; re-validated as a general
 *   3: BOOL   - true if this is the Factory purchase path
 *
 * Returns: nothing.
 *
 * Side effects on success:
 *   - debits "money" by getBusinessPrice (resistance funds)
 *   - pushes _name into "GEURowned" (broadcast)
 *   - sets "<name>employ" = 2 with broadcast=true so GUERLoop sees it
 *   - changes the marker color to ColorGUER (global)
 *   - calls OT_fnc_resetSpawn at _pos
 *   - notifies everyone the business is operational
 *   - for Factory: spawns the cargo container if missing and assigns
 *     ownership to the first general
 */

SERVER_ONLY;

params [
    ["_name", "", [""]],
    ["_pos", [0,0,0], [[]]],
    ["_generalUid", "", [""]],
    ["_isFactory", false, [false]]
];

if (_name isEqualTo "") exitWith {};
if (_generalUid isEqualTo "") exitWith {};

// Re-validate the caller is a general server-side. The client-side
// playerIsGeneral check is for UX; the authoritative check lives here
// to prevent a tampered client from buying as a non-general.
private _generals = server getVariable ["generals", []];
if !(_generalUid in _generals) exitWith {
    private _msg = format ["buyBusinessServer: reject non-general uid=%1 name=%2", _generalUid, _name];
    BO_LOG_INFO("admin", _msg);
};

// Atomic check-then-set on GEURowned. Done in one server frame, so
// two concurrent client buys cannot both pass the !(_name in _owned)
// gate.
private _owned = server getVariable ["GEURowned", []];
if (_name in _owned) exitWith {};

private _price = _name call OT_fnc_getBusinessPrice;
private _funds = server getVariable ["money", 0];
if (_funds < _price) exitWith {
    "The resistance cannot afford this" remoteExec ["OT_fnc_notifyMinor", _generalUid, false];
};

// Debit funds and commit ownership in the same server tick.
server setVariable ["money", _funds - _price, true];
server setVariable ["GEURowned", _owned + [_name], true];
// MP fix: third arg `true` so dedicated-server GUERLoop and
// spawnBusinessEmployees see the initial employ=2 and spawn workers.
server setVariable [format ["%1employ", _name], 2, true];

_pos remoteExec ["OT_fnc_resetSpawn", 2, false];
format ["%1 is now operational", _name] remoteExec ["OT_fnc_notifyMinor", 0, false];
// Targeted confirmation to the buying general so the audit loop closes
// on their HUD too -- the global banner above does not tell the actor
// what they paid, and the resistance-funds drop is easy to miss when
// it's a small fraction of the treasury. Closes the "did my buy go
// through?" UX gap on dedicated MP.
format ["You bought %1 for $%2", _name, _price] remoteExec ["OT_fnc_notifyGood", _generalUid, false];
// setMarkerColor (no "Local") is a global command; safe from server.
_name setMarkerColor "ColorGUER";

if (_isFactory) then {
    private _veh = _pos nearestObject OT_item_CargoContainer;
    if (_veh isEqualTo objNull) then {
        private _p = _pos findEmptyPosition [5, 100, OT_item_CargoContainer];
        _veh = OT_item_CargoContainer createVehicle _p;
        private _firstGeneral = _generals param [0, ""];
        [_veh, _firstGeneral] call OT_fnc_setOwner;
        clearWeaponCargoGlobal _veh;
        clearMagazineCargoGlobal _veh;
        clearBackpackCargoGlobal _veh;
        clearItemCargoGlobal _veh;
    };

    // Multi-factory: register the starter (or any pre-baked factory
    // building at _pos) with the production registry so the PFH tick
    // starts processing it immediately. The starter at OT_factoryPos
    // wasn't auto-registered at postInit because GEURowned didn't
    // include "Factory" then -- this purchase is the trigger.
    if (!isNil "OT_factory") then {
        private _factoryObj = _pos nearestObject OT_factory;
        if (!isNull _factoryObj && {(_factoryObj distance _pos) < 50}) then {
            _veh setVariable ["BO_factoryCrate", true, true];
            // Owner-back-reference: save/load + replaceStructureCrate
            // walk crates and re-bind by reading BO_factoryOwner. Without
            // this the rebind two-pass loses the link on the first
            // round-trip after purchase.
            _veh setVariable ["BO_factoryOwner", _factoryObj, true];
            _factoryObj setVariable ["BO_outputContainer", _veh, true];
            if (isNil { _factoryObj getVariable "BO_queue" })          then { _factoryObj setVariable ["BO_queue", [], true] };
            if (isNil { _factoryObj getVariable "BO_producing" })      then { _factoryObj setVariable ["BO_producing", "", true] };
            if (isNil { _factoryObj getVariable "BO_producetime" })    then { _factoryObj setVariable ["BO_producetime", 0, true] };
            if (isNil { _factoryObj getVariable "BO_factoryEnabled" }) then { _factoryObj setVariable ["BO_factoryEnabled", true, true] };
            if (isNil { _factoryObj getVariable "BO_factoryName" })    then { _factoryObj setVariable ["BO_factoryName", "", true] };
            [_factoryObj] call BO_fnc_registerFactory;
        };
    };
};

[AUDIT_ADMIN,
 format ["buyBusiness uid=%1 name=%2 price=%3 factory=%4",
    _generalUid, _name, _price, _isFactory],
 [_generalUid, _name, _price, _isFactory],
 "",
 ""
] call BO_fnc_auditServer;
