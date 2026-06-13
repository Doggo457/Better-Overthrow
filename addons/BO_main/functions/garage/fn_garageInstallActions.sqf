#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garageInstallActions
 *
 * Per-client postInit: register ACE Main Actions for the persistent
 * garage system.
 *
 *   - Garage main action on OT_warehouse (condition: warehouse is owned)
 *   - Garage as captured action on LandVehicle / Air base classes
 *     (condition: NATO/unowned vehicle stopped within radius of an
 *      owned warehouse and the player is the driver)
 *
 * Idempotent. Mirrors BO_fnc_addLogisticsContainerActions for the ACE
 * registration shape.
 */

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["BO_garageActionsInstalled", false]) exitWith {};
missionNamespace setVariable ["BO_garageActionsInstalled", true];

[] spawn {
    waitUntil { sleep 0.5; !isNull player && {!isNil "OT_warehouse"} };

    if (isNil "ace_interact_menu_fnc_createAction" || {isNil "ace_interact_menu_fnc_addActionToClass"}) exitWith {
        BO_LOG_WARN("garage", "ACE interact menu API not loaded -- skipping garage action registration");
    };

    // -----------------------------------------------------------------
    // ACE Main Action on OT_warehouse class: open the garage dialog.
    // Condition gate: the target warehouse must be in the owned list.
    // -----------------------------------------------------------------
    private _whAction = [
        "BO_garageOpen",
        "Garage",
        "",
        {
            params ["_target"];
            [_target] spawn BO_fnc_garageDialog;
        },
        {
            params ["_target"];
            private _owned = warehouse getVariable ["owned", []];
            _target in _owned
        }
    ] call ace_interact_menu_fnc_createAction;

    [OT_warehouse, 0, ["ACE_MainActions"], _whAction] call ace_interact_menu_fnc_addActionToClass;

    // -----------------------------------------------------------------
    // Captured-vehicle action on LandVehicle + Air base classes.
    // Visibility gated to: player is driver, vehicle stopped, vehicle
    // is NATO/unowned, an owned warehouse is within radius.
    // -----------------------------------------------------------------
    private _capCond = {
        params ["_target"];
        if (isNull _target || {!alive _target}) exitWith { false };
        if (driver _target isNotEqualTo player) exitWith { false };
        if (speed _target > 1) exitWith { false };
        private _hasOwner = _target call OT_fnc_hasOwner;
        private _owner = _target call OT_fnc_getOwner;
        if (_hasOwner && {_owner isNotEqualTo ""} && {_owner isNotEqualTo "NATO"}) exitWith { false };
        private _r = ["bo_garage_auto_radius", 75] call BIS_fnc_getParamValue;
        private _owned = warehouse getVariable ["owned", []];
        (_owned findIf { _x distance _target < _r }) >= 0
    };

    private _capStatement = {
        params ["_target"];
        private _veh = _target;
        private _r = ["bo_garage_auto_radius", 75] call BIS_fnc_getParamValue;
        private _owned = warehouse getVariable ["owned", []];
        private _wh = objNull;
        {
            if (_x distance _veh < _r) exitWith { _wh = _x };
        } forEach _owned;
        if (isNull _wh) exitWith {
            "No owned warehouse within range" call OT_fnc_notifyBad;
        };
        [_veh, getPlayerUID player, name player, _wh] remoteExec ["BO_fnc_garageStore", 2, false];
    };

    private _capAction = [
        "BO_garageCaptureNATO",
        "Garage as captured",
        "",
        _capStatement,
        _capCond
    ] call ace_interact_menu_fnc_createAction;

    ["LandVehicle", 0, ["ACE_MainActions"], _capAction] call ace_interact_menu_fnc_addActionToClass;
    ["Air",         0, ["ACE_MainActions"], _capAction] call ace_interact_menu_fnc_addActionToClass;

    BO_LOG_INFO("garage", "Garage ACE actions installed (warehouse + capture)");
};
