#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_casPickTarget
 *
 * Stage 2 of the CAS flow: map-click target, confirm via
 * OT_fnc_playerDecision, remoteExec BO_fnc_callCAS.
 *
 * Pattern parallels BO_fnc_fireMissionPickTarget.
 */

private _pad = missionNamespace getVariable ["BO_casHelipad", objNull];
if (isNull _pad) exitWith {};

"Click map to mark CAS target. ESC to cancel." call OT_fnc_notifyMinor;
openMap [true, false];

BO_casMapClickEH = addMissionEventHandler ["MapSingleClick", {
    params ["", "_pos"];
    if (!isNil "BO_casMapClickEH") then {
        removeMissionEventHandler ["MapSingleClick", BO_casMapClickEH];
        BO_casMapClickEH = nil;
    };
    if (!isNil "BO_casMapCloseEH") then {
        removeMissionEventHandler ["Map", BO_casMapCloseEH];
        BO_casMapCloseEH = nil;
    };
    openMap false;

    private _pad   = missionNamespace getVariable ["BO_casHelipad", objNull];
    private _cls   = missionNamespace getVariable ["BO_casVehClass", ""];
    private _cost  = missionNamespace getVariable ["BO_casCost", 8000];
    if (isNull _pad || {_cls isEqualTo ""}) exitWith {};

    private _displayName = _cls call OT_fnc_vehicleGetName;
    private _costFmt = [_cost, 1, 0, true] call CBA_fnc_formatNumber;

    private _opts = [];
    private _header = format ["<t align='center' size='1.1'>Confirm CAS</t><br/><t align='center' size='0.85'>%1 -> grid %2</t><br/><t align='center' size='0.85'>Cost: $%3 (bank)</t>",
        _displayName, mapGridPosition _pos, _costFmt];
    _opts pushBack _header;
    _opts pushBack [
        "Confirm",
        {
            params ["_pad", "_cls", "_pos", "_cost"];
            [_pad, _cls, _pos, _cost, getPlayerUID player] remoteExec ["BO_fnc_callCAS", 2, false];
        },
        [_pad, _cls, _pos, _cost]
    ];
    _opts pushBack ["Cancel", {}];
    _opts call OT_fnc_playerDecision;
}];

// Cleanup on map close (ESC). Same rationale as
// BO_fnc_fireMissionPickTarget -- prevents the stale handler from
// firing on an unrelated map click later.
BO_casMapCloseEH = addMissionEventHandler ["Map", {
    params ["_mapIsOpened"];
    if (_mapIsOpened) exitWith {};
    if (!isNil "BO_casMapClickEH") then {
        removeMissionEventHandler ["MapSingleClick", BO_casMapClickEH];
        BO_casMapClickEH = nil;
    };
    if (!isNil "BO_casMapCloseEH") then {
        removeMissionEventHandler ["Map", BO_casMapCloseEH];
        BO_casMapCloseEH = nil;
    };
}];
