#include "\overthrow_main\script_component.hpp"
/*
 * OT_fnc_onNameDone -- BO override
 *
 * Called from OT_dialog_name's Done button after the player places a
 * FOB flag and types a name. Registers the flag in the resistance
 * `bases` array and drops a map marker for it.
 *
 * Vanilla OT used a fixed 50m nearObjects search to find the flag,
 * which sometimes missed it if the player walked off while typing or
 * if OT_flag_IND resolves to something obscure on a non-stock map.
 * This version walks a 50 -> 150m sweep, falls back to "the only
 * unowned flag the player owns within 250m" as a last resort, and
 * logs every step so the dispatch path is observable in the RPT.
 *
 * Diagnostic note: the most common report of "Done does nothing" turns
 * out to be a missing OT_inputHandler global from a previous OT input
 * dialog still set, OR the player hitting Done with an empty edit
 * field (which routes to the refund branch). Both are visible in the
 * INFO log line emitted here.
 */

// Hint AND log on entry so the player can confirm the action fired.
// If they click Done and see neither, the OT_dialog_name button's
// action string itself isn't reaching us (compiled-config issue,
// not anything we can fix in SQF).
hint "Registering FOB...";

private _name = ctrlText 1400;

private _logMsg = format ["FOB Done clicked: name='%1', flagCls='%2'", _name, OT_flag_IND];
BO_LOG_INFO("admin", _logMsg);

if (_name isEqualTo "") exitWith {
    closeDialog 0;
    private _base = (player nearObjects [OT_flag_IND, 150]) param [0, objNull];
    if (!isNull _base) then { deleteVehicle _base };
    hint "You must give a name for the base!\nYour money has been refunded.";
    [250] call OT_fnc_money;
};

closeDialog 0;

// Sweep at increasing radii. 50m is the vanilla default; 150m covers
// players who drifted; 250m is the bail-out before we give up.
private _base = objNull;
{
    private _candidates = player nearObjects [OT_flag_IND, _x];
    private _ownIdx = _candidates findIf {
        (_x call OT_fnc_getOwner) isEqualTo getPlayerUID player
    };
    if (_ownIdx >= 0) exitWith {
        _base = _candidates select _ownIdx;
    };
    // Even if no ownership tag was set yet, the nearest flag at this
    // radius is the most likely match if it's the only one.
    if (count _candidates > 0) exitWith {
        _base = _candidates select 0;
    };
} forEach [50, 150, 250];

if (isNull _base) exitWith {
    BO_LOG_WARN("admin", "FOB Done: no flag found within 250m -- nothing registered");
    "Couldn't find the flag you just placed -- try again closer to it" call OT_fnc_notifyMinor;
};

private _basePos = getPosASL _base;
_basePos set [2, 0];

// MP race: client read+push+broadcast of "bases" loses entries when two
// players place FOBs concurrently. Route through server-only adjuster.
private _newBaseEntry = [_basePos, _name, getPlayerUID player];
[_newBaseEntry] remoteExec ["BO_fnc_registerBase", 2, false];

_base setVariable ["name", _name, true];

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
