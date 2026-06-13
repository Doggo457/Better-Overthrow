#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_commitNewFOB
 *
 * Input-dialog handler set by fn_place when the player places a FOB
 * flag. OT_context carries the just-placed flag object; this function
 * reads the player's chosen name from IDC 1400 and registers the
 * base. Mirror of BO_fnc_renameFOB, which uses the same input-dialog
 * pattern.
 *
 * Replaces the vanilla `createDialog "OT_dialog_name"` flow. That
 * dialog's Done button is hardcoded to `_this call OT_fnc_onNameDone`
 * at the compiled-config level and the action wasn't reaching the
 * function on the user's setup -- we route through OT_dialog_input
 * (the same dialog the Rename flow uses) which is known good.
 *
 * Failure handling: empty name refunds money and deletes the flag,
 * matching the vanilla behaviour. Missing OT_context (somehow the
 * handler fires without a flag reference) is logged and ignored.
 */

private _name = ctrlText 1400;
private _flag = OT_context;

if (isNull _flag) exitWith {
    BO_LOG_WARN("admin", "commitNewFOB: OT_context is null -- flag reference lost");
    "FOB reference lost -- try placing again" call OT_fnc_notifyMinor;
};

if (_name isEqualTo "") exitWith {
    deleteVehicle _flag;
    hint "You must give a name for the base!\nYour money has been refunded.";
    [250] call OT_fnc_money;
};

private _basePos = getPosASL _flag;
_basePos set [2, 0];

// MP race: client read+push+broadcast of "bases" loses entries when two
// players place FOBs concurrently. Route through server-only adjuster.
private _newBaseEntry = [_basePos, _name, getPlayerUID player];
[_newBaseEntry] remoteExec ["BO_fnc_registerBase", 2, false];

_flag setVariable ["name", _name, true];

private _mrkid = format ["%1-base", _basePos];
createMarkerLocal [_mrkid, _basePos];
_mrkid setMarkerShapeLocal "ICON";
_mrkid setMarkerTypeLocal "mil_Flag";
_mrkid setMarkerColorLocal "ColorWhite";
_mrkid setMarkerAlphaLocal 1;
_mrkid setMarkerText _name;

private _doneMsg = format ["FOB registered: '%1' at %2", _name, _basePos];
BO_LOG_INFO("admin", _doneMsg);
[AUDIT_ADMIN, _doneMsg, [_name, _basePos]] call BO_fnc_audit;

private _builder = name player;
{
    [
        _x,
        format ["New Base: %1", _name],
        format ["%1 created a new base for resistance efforts %2", _builder, _basePos call BIS_fnc_locationDescription]
    ] call BIS_fnc_createLogRecord;
} forEach ([] call CBA_fnc_players);

private _note = format ["FOB '%1' registered", _name];
_note call OT_fnc_notifyGood;
