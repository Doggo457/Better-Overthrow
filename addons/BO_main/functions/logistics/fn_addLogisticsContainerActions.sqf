#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_addLogisticsContainerActions
 *
 * Per-client postInit: register ACE Main Actions on every cargo
 * container we expect the player to interact with for logistics.
 *
 * After two failed attempts to rely on base-class inheritance
 * (Slingload_01_base_F was the wrong casing; ReammoBox_F should
 * have worked but the menu still didn't appear on the user's setup),
 * this version registers on each SPECIFIC classname explicitly.
 * Verbose but bulletproof -- the only way an action doesn't show
 * up is if its condition returns false or the engine fails the
 * registration outright, both of which the diagnostic diag_log
 * lines below would catch.
 *
 * Conditions are always-true / state-based, no ownership gates,
 * so OT-spawned containers (no player owner UID) still show the
 * menu.
 */

diag_log "[BO_logistics] addLogisticsContainerActions: ENTRY";

if (!hasInterface) exitWith {
    diag_log "[BO_logistics] no interface -- aborting";
};
if (missionNamespace getVariable ["BO_logisticsActionsInstalled", false]) exitWith {
    diag_log "[BO_logistics] already installed -- aborting (idempotent guard)";
};
missionNamespace setVariable ["BO_logisticsActionsInstalled", true];

diag_log "[BO_logistics] spawning registration thread";

[] spawn {
    diag_log "[BO_logistics] spawn started, waiting for player";
    waitUntil { sleep 0.5; !isNull player };
    diag_log format ["[BO_logistics] player exists (%1), beginning ACE registration", name player];

    if (isNil "ace_interact_menu_fnc_createAction") then {
        diag_log "[BO_logistics] ERROR: ace_interact_menu_fnc_createAction is nil -- ACE not loaded?";
    };
    if (isNil "ace_interact_menu_fnc_addActionToClass") then {
        diag_log "[BO_logistics] ERROR: ace_interact_menu_fnc_addActionToClass is nil -- ACE not loaded?";
    };

    private _untaggedCond = {
        (_target getVariable ["BO_logisticsRole", ""]) isEqualTo ""
    };
    private _taggedCond = {
        (_target getVariable ["BO_logisticsRole", ""]) isNotEqualTo ""
    };

    private _root = [
        "BO_logRoot",
        "Logistics",
        "",
        {},
        { true }
    ] call ace_interact_menu_fnc_createAction;
    diag_log format ["[BO_logistics] root action created: %1", _root];

    private _setSource = [
        "BO_logSetSrc",
        "Set as source",
        "",
        {
            diag_log "[BO_logistics] Set as source clicked";
            OT_context = _target;
            OT_inputHandler = {
                private _label = ctrlText 1400;
                if (_label isEqualTo "") then { _label = "Source" };
                [OT_context, "SOURCE", _label] call BO_fnc_logisticsSetRole;
            };
            ["<t align='center'>Source label</t>", "Source"] call OT_fnc_inputDialog;
        },
        _untaggedCond
    ] call ace_interact_menu_fnc_createAction;
    diag_log format ["[BO_logistics] setSource action created: %1", _setSource];

    private _setDest = [
        "BO_logSetDst",
        "Set as destination",
        "",
        {
            diag_log "[BO_logistics] Set as destination clicked";
            OT_context = _target;
            OT_inputHandler = {
                private _label = ctrlText 1400;
                if (_label isEqualTo "") then { _label = "Destination" };
                [OT_context, "DEST", _label] call BO_fnc_logisticsSetRole;
            };
            ["<t align='center'>Destination label</t>", "Destination"] call OT_fnc_inputDialog;
        },
        _untaggedCond
    ] call ace_interact_menu_fnc_createAction;
    diag_log format ["[BO_logistics] setDest action created: %1", _setDest];

    private _clear = [
        "BO_logClear",
        "Clear logistics role",
        "",
        {
            diag_log "[BO_logistics] Clear role clicked";
            [_target, ""] call BO_fnc_logisticsSetRole;
        },
        _taggedCond
    ] call ace_interact_menu_fnc_createAction;
    diag_log format ["[BO_logistics] clear action created: %1", _clear];

    // Every BIS cargo-container class the player can plausibly tag.
    // Registering on each one individually instead of relying on a
    // shared base class, because that's repeatedly failed to apply.
    private _classes = [
        // Slingload containers
        "B_Slingload_01_Cargo_F",
        "O_Slingload_01_Cargo_F",
        "I_Slingload_01_Cargo_F",
        // Cargo nets (OT spawn ammobox = B_CargoNet_01_ammo_F on every map)
        "B_CargoNet_01_ammo_F",
        "O_CargoNet_01_ammo_F",
        "I_CargoNet_01_ammo_F",
        "B_CargoNet_01_box_F",
        "O_CargoNet_01_box_F",
        "I_CargoNet_01_box_F",
        // Faction ammo crates
        "Box_NATO_AmmoVeh_F",
        "Box_East_AmmoVeh_F",
        "Box_IND_AmmoVeh_F",
        "Box_NATO_Ammo_F",
        "Box_East_Ammo_F",
        "Box_IND_Ammo_F",
        // Supply crate
        "B_supplyCrate_F",
        // ACE / generic fallback (in case mods extend from these)
        "ReammoBox_F"
    ];

    {
        private _cls = _x;
        [_cls, 0, ["ACE_MainActions"],                     _root]      call ace_interact_menu_fnc_addActionToClass;
        [_cls, 0, ["ACE_MainActions", "BO_logRoot"],       _setSource] call ace_interact_menu_fnc_addActionToClass;
        [_cls, 0, ["ACE_MainActions", "BO_logRoot"],       _setDest]   call ace_interact_menu_fnc_addActionToClass;
        [_cls, 0, ["ACE_MainActions", "BO_logRoot"],       _clear]     call ace_interact_menu_fnc_addActionToClass;
        diag_log format ["[BO_logistics] registered on class: %1", _cls];
    } forEach _classes;

    diag_log format ["[BO_logistics] ALL DONE: registered on %1 classes", count _classes];
    BO_LOG_INFO("logistics", "ACE Logistics submenu registered (specific class list)");
};
