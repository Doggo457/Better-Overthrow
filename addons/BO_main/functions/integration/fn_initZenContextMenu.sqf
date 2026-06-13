#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initZenContextMenu
 *
 * Register BO right-click context menu actions in Zeus Enhanced.
 *
 * API (verified against zen-mod/ZEN master):
 *
 *   createAction takes 8 args, returns a 9-element action array:
 *     [_actionName, _displayName, _icon,
 *      _statement, _condition,
 *      _args, _insertChildren, _modifierFunction]
 *
 *   addAction takes [_action, _parentPath, _priority].
 *
 *   When Zen fires the statement / condition it passes ACTION_PARAMS
 *   = [_position, _objects, _groups, _waypoints, _markers,
 *      _hoveredEntity, _args] -- the same magic-variable shape OT's
 *   description.ext entries use. The entity under the cursor is
 *   _hoveredEntity (index 5), NOT _this select 0. Reading index 0 as
 *   a unit gives an array (the cursor position) and isKindOf throws
 *   "Type Array, expected String,Object" every frame the menu is
 *   evaluated, which produces RPT spam heavy enough to make Zeus
 *   feel hung.
 */

if (!hasInterface) exitWith {};
if (isNil "zen_context_menu_fnc_addAction") exitWith {};
if (missionNamespace getVariable ["BO_zenContextInstalled", false]) exitWith {};
missionNamespace setVariable ["BO_zenContextInstalled", true];

// Set Money is already registered by OT via the mission's
// description.ext (`class zen_context_menu_actions { class ot_setmoney
// { ... } }`). Registering it at runtime here would duplicate the
// entry. Only Set Bank gets a runtime registration.

private _setBankAction = [
    "BO_setBank",
    "Overthrow: Set Bank",
    "\overthrow_main\ui\markers\shop-General.paa",
    {
        params ["", "", "", "", "", "_hoveredEntity"];
        [_hoveredEntity] call BO_fnc_zenSetBankContext;
    },
    {
        params ["", "", "", "", "", "_hoveredEntity"];
        // Admin-only (NOT OT_adminMode -- Generals carry that flag but
        // economy editing belongs to the full-Zeus tier).
        _hoveredEntity isKindOf "CAManBase" && {isPlayer _hoveredEntity}
            && {(isServer && hasInterface) || {(call BIS_fnc_admin) isEqualTo 2}}
    }
] call zen_context_menu_fnc_createAction;

[_setBankAction, [], 49] call zen_context_menu_fnc_addAction;

// BO: Restore-previous-save admin entry. Surfaces the .prev backup
// slot written by BO_fnc_backupSave as a one-click rollback when the
// current save is suspected corrupt. Admin / General gated; the
// statement remoteExecs to server (target 2).
private _restorePrevSaveAction = [
    "BO_restorePrevSave",
    "Overthrow: Restore Previous Save",
    "\overthrow_main\ui\markers\shop-General.paa",
    {
        [] remoteExec ["BO_fnc_restorePrevSave", 2, false];
        "Restore-previous-save dispatched to server" call OT_fnc_notifyMinor;
    },
    {
        // Host/logged-in admin ONLY. The old OT_adminMode gate leaked
        // this to every General (BO grants them the flag) -- a save
        // rollback is too destructive for the high-command tier.
        (isServer && hasInterface) || {(call BIS_fnc_admin) isEqualTo 2}
    }
] call zen_context_menu_fnc_createAction;

[_restorePrevSaveAction, [], 48] call zen_context_menu_fnc_addAction;

// BO: Toggle General on the hovered player. Admin/General gated so a
// non-host can't bootstrap themselves into the role.
private _toggleGeneralAction = [
    "BO_toggleGeneral",
    "Overthrow: Toggle General",
    "\overthrow_main\ui\markers\shop-General.paa",
    {
        params ["", "", "", "", "", "_hoveredEntity"];
        [_hoveredEntity] remoteExec ["BO_fnc_zenToggleGeneral", 2, false];
        private _wasGen = (getPlayerUID _hoveredEntity) in (server getVariable ["generals", []]);
        private _verb = if (_wasGen) then { "Demoting" } else { "Promoting" };
        private _hmsg = format ["%1 %2...", _verb, name _hoveredEntity];
        _hmsg call OT_fnc_notifyMinor;
    },
    {
        params ["", "", "", "", "", "_hoveredEntity"];
        // Host/logged-in admin ONLY. With the old OT_adminMode gate any
        // General could promote/demote Generals from restricted Zeus --
        // the role chain must stop at admin (mirrors fn_makeGeneral).
        _hoveredEntity isKindOf "CAManBase" && {isPlayer _hoveredEntity}
            && {(isServer && hasInterface) || {(call BIS_fnc_admin) isEqualTo 2}}
    }
] call zen_context_menu_fnc_createAction;

[_toggleGeneralAction, [], 47] call zen_context_menu_fnc_addAction;

BO_LOG_INFO("admin", "Zen right-click context actions registered (Set Bank, Restore Previous Save, Toggle General)");
