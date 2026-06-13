#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_addArtilleryActions
 *
 * Per-client postInit (mirrors BO_fnc_addATMActions /
 * BO_fnc_addLogisticsContainerActions). Registers:
 *
 *   - "Call Fire Mission" on B_Mortar_01_F (gated on cooldown elapsed)
 *   - "Fire Mission (on cooldown)" companion stub on same class
 *     (inverse condition; shows remaining seconds)
 *   - "Request CAS" on each of the four buildable helipad classes
 *     (Land_HelipadCircle_F / Civil / Rescue / Square), gated on
 *     BO_helipadCASEnabled + cooldown + a CAS-loadout heli parked
 *     within 40m
 *
 * Idempotent via BO_artilleryActionsInstalled.
 */

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["BO_artilleryActionsInstalled", false]) exitWith {};
missionNamespace setVariable ["BO_artilleryActionsInstalled", true];

[] spawn {
    waitUntil { sleep 0.5; !isNull player };

    if (isNil "ace_interact_menu_fnc_createAction") exitWith {
        BO_LOG_WARN("artillery", "ACE not loaded -- skipping artillery action registration");
    };

    // ---- Mortar: Call Fire Mission ----
    // All artillery + CAS actions are Generals-only. The condition
    // call OT_fnc_playerIsGeneral is the client-side visibility gate;
    // the server-side callFireMission / callCAS / registerCASHelipad
    // re-check authoritatively in case of a spoofed remoteExec.
    private _fmAction = [
        "BO_callFireMission",
        "Call Fire Mission",
        "",
        { [_target] call BO_fnc_fireMissionDialog },
        {
            if !(call OT_fnc_playerIsGeneral) exitWith { false };
            private _last = _target getVariable ["BO_lastFireMission", 0];
            private _cd   = _target getVariable ["BO_mortarCooldown", 300];
            (serverTime - _last) >= _cd
        },
        {},
        [],
        [0, 0, 0.5]
    ] call ace_interact_menu_fnc_createAction;
    ["B_Mortar_01_F", 0, ["ACE_MainActions"], _fmAction] call ace_interact_menu_fnc_addActionToClass;

    // Cooldown-pending companion so the player sees "on cooldown"
    // rather than the action silently disappearing. Also Generals-only.
    private _cdAction = [
        "BO_fireMissionCooldown",
        "Fire Mission (on cooldown)",
        "",
        {
            private _last = _target getVariable ["BO_lastFireMission", 0];
            private _cd   = _target getVariable ["BO_mortarCooldown", 300];
            private _rem  = (_last + _cd - serverTime) max 0;
            private _msg = format ["Fire mission ready in %1s", round _rem];
            _msg call OT_fnc_notifyMinor;
        },
        {
            if !(call OT_fnc_playerIsGeneral) exitWith { false };
            private _last = _target getVariable ["BO_lastFireMission", 0];
            private _cd   = _target getVariable ["BO_mortarCooldown", 300];
            (serverTime - _last) < _cd
        }
    ] call ace_interact_menu_fnc_createAction;
    ["B_Mortar_01_F", 0, ["ACE_MainActions"], _cdAction] call ace_interact_menu_fnc_addActionToClass;

    // ---- Helipad: Request CAS ---- Generals-only.
    private _casAction = [
        "BO_requestCAS",
        "Request CAS",
        "",
        { [_target] call BO_fnc_casDialog },
        {
            if !(call OT_fnc_playerIsGeneral) exitWith { false };
            // Helipad must be registered as CAS-capable + not on cooldown
            // and a CAS-loadout heli must be parked within 40m.
            if !(_target getVariable ["BO_helipadCASEnabled", false]) exitWith { false };
            private _last = _target getVariable ["BO_lastCASMission", 0];
            private _cd = missionNamespace getVariable ["BO_casCooldownSec", 1200];
            if ((serverTime - _last) < _cd) exitWith { false };
            if (isNil "BO_casLoadouts") exitWith { false };
            private _nearby = (getPosATL _target) nearObjects ["Helicopter", 40];
            private _supportedClasses = keys BO_casLoadouts;
            (_nearby findIf { (typeOf _x) in _supportedClasses && {alive _x} }) >= 0
        }
    ] call ace_interact_menu_fnc_createAction;

    // Enable CAS action -- one-shot per helipad. Also Generals-only.
    private _enableCASAction = [
        "BO_enableCAS",
        "Enable CAS dispatch",
        "",
        {
            [_target, getPlayerUID player] remoteExec ["BO_fnc_registerCASHelipad", 2, false];
            "CAS dispatch enabled at helipad" call OT_fnc_notifyGood;
        },
        {
            if !(call OT_fnc_playerIsGeneral) exitWith { false };
            !(_target getVariable ["BO_helipadCASEnabled", false])
        }
    ] call ace_interact_menu_fnc_createAction;

    // Apply to every OT-buildable helipad class.
    private _helipadClasses = [
        "Land_HelipadCircle_F",
        "Land_HelipadCivil_F",
        "Land_HelipadRescue_F",
        "Land_HelipadSquare_F"
    ];
    {
        [_x, 0, ["ACE_MainActions"], _enableCASAction] call ace_interact_menu_fnc_addActionToClass;
        [_x, 0, ["ACE_MainActions"], _casAction] call ace_interact_menu_fnc_addActionToClass;
    } forEach _helipadClasses;

    BO_LOG_INFO("artillery", "Artillery + CAS ACE actions registered");
};
