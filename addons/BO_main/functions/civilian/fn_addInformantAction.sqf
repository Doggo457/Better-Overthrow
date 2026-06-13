#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_addInformantAction
 *
 * Per-client ACE Interact registration. Adds a "Talk" Main Action
 * to OT_civType_local that only shows when target.BO_isInformant
 * is true. On activate, remoteExec'd to the server which validates
 * and credits the player.
 *
 * Idempotent via BO_informantActionsInstalled.
 */

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["BO_informantActionsInstalled", false]) exitWith {};
missionNamespace setVariable ["BO_informantActionsInstalled", true];

[] spawn {
    waitUntil { sleep 0.5; !isNull player };

    if (isNil "ace_interact_menu_fnc_createAction") exitWith {
        BO_LOG_WARN("civilian","ace_interact_menu_fnc_createAction nil -- ACE not loaded?");
    };

    private _action = [
        "BO_talkInformant",
        "Talk",
        "",
        { [_target, getPlayerUID _player] remoteExec ["BO_fnc_civilianEventTalk", 2, false]; },
        { _target getVariable ["BO_isInformant", false] && {alive _target} }
    ] call ace_interact_menu_fnc_createAction;

    // OT_civType_local is the base civilian class BO uses for spawned
    // informants. It's set in OT's per-map initVar.sqf so by the time
    // this thread runs OT_civType_local is in scope on the client.
    private _baseClass = if (!isNil "OT_civType_local") then { OT_civType_local } else { "C_man_1" };

    // Enable inheritance so any CAManBase descendant carrying the
    // BO_isInformant flag exposes the Talk action -- defends against a
    // future spawn path that uses a different civ class than the
    // current OT_civType_local exact match.
    [
        _baseClass, 0, ["ACE_MainActions"], _action, true
    ] call ace_interact_menu_fnc_addActionToClass;

    private _msg = format ["Informant Talk action registered on %1", _baseClass];
    BO_LOG_INFO("civilian", _msg);
};
