#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_renameFOB
 *
 * Open the OT input dialog with the current FOB's name pre-filled,
 * and wire OT_inputHandler to commit the rename.
 *
 * Flow:
 *   1. Find the FOB the player is standing in (within 100m of an
 *      OT_flag_IND they own).
 *   2. Stash the flag object in OT_context so the input handler can
 *      look it up after closeDialog 0 (OT input dialog clears the
 *      ctrl state on close so we can't read it from inside the
 *      handler).
 *   3. Set OT_inputHandler to the commit closure: rewrite the
 *      matching server `bases` entry, update the flag's "name" var,
 *      and refresh the map marker (delete the old `<oldPos>-base`
 *      marker and create a new one with the same position but the
 *      new label).
 *   4. Open OT_dialog_input with the current name as default.
 *
 * Audit: rename produces a `admin` audit entry so the change is
 * traceable alongside FOB creation in the Y -> Audit Log view.
 *
 * Permissions: only the FOB owner or a General can rename. The
 * Y-menu injection already gates visibility, but we re-check here
 * so a forged remoteExec can't bypass the UI.
 */

if (!hasInterface) exitWith {};

// Locate the player's FOB.
private _candidates = player nearObjects [OT_flag_IND, 100];
private _flag = objNull;
{
    private _ownerUID = _x call OT_fnc_getOwner;
    if (_ownerUID isEqualTo getPlayerUID player) exitWith { _flag = _x };
} forEach _candidates;

if (isNull _flag) exitWith {
    "No FOB you own within range" call OT_fnc_notifyMinor;
};

private _currentName = _flag getVariable ["name", "Base"];

OT_context = _flag;

OT_inputHandler = {
    private _newName = ctrlText 1400;
    if (_newName isEqualTo "") exitWith {
        "Name cannot be empty" call OT_fnc_notifyMinor;
    };

    private _flag = OT_context;
    if (isNull _flag) exitWith {
        "FOB reference lost" call OT_fnc_notifyMinor;
    };

    private _oldName = _flag getVariable ["name", "Base"];

    // MP race: client read+mutate+broadcast of "bases" loses concurrent
    // edits. Route the rename through the server-only adjuster which
    // also propagates the flag's "name" setVariable.
    [_flag, _newName] remoteExec ["BO_fnc_renameBase", 2, false];

    private _basePos = getPosASL _flag;
    _basePos set [2, 0];

    // Refresh the marker. The marker id is keyed on _basePos so
    // there's only one to swap.
    private _mrkid = format ["%1-base", _basePos];
    deleteMarkerLocal _mrkid;
    createMarkerLocal [_mrkid, _basePos];
    _mrkid setMarkerShapeLocal "ICON";
    _mrkid setMarkerTypeLocal "mil_Flag";
    _mrkid setMarkerColorLocal "ColorWhite";
    _mrkid setMarkerAlphaLocal 1;
    _mrkid setMarkerText _newName;

    private _msg = format ["FOB renamed: '%1' -> '%2'", _oldName, _newName];
    [AUDIT_ADMIN, _msg, [_oldName, _newName, _basePos]] call BO_fnc_audit;
    _msg call OT_fnc_notifyMinor;
};

[
    format ["<t align='center'>Rename FOB</t><br/><t align='center' size='0.8'>Current: %1</t>", _currentName],
    _currentName
] call OT_fnc_inputDialog;
