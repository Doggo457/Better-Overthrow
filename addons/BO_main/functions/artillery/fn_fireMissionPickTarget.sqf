#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_fireMissionPickTarget
 *
 * Stage 3 of the fire-mission flow. Opens the map, adds a single-shot
 * MapSingleClick mission EH, and on click presents a confirm dialog
 * via OT_fnc_playerDecision. Confirm dispatches the mission to the
 * server via remoteExec BO_fnc_callFireMission.
 *
 * Pattern verified against fn_fastTravel.sqf (addMissionEventHandler
 * MapSingleClick + openMap toggle).
 */

private _mortar = missionNamespace getVariable ["BO_fmMortar", objNull];
private _shell  = missionNamespace getVariable ["BO_fmShellType", ""];
private _count  = missionNamespace getVariable ["BO_fmCount", 0];
if (isNull _mortar || {_shell isEqualTo ""} || {_count <= 0}) exitWith {};

"Click map to select fire mission target. ESC to cancel." call OT_fnc_notifyMinor;
openMap [true, false];

BO_fmMapClickEH = addMissionEventHandler ["MapSingleClick", {
    params ["", "_pos"];
    if (!isNil "BO_fmMapClickEH") then {
        removeMissionEventHandler ["MapSingleClick", BO_fmMapClickEH];
        BO_fmMapClickEH = nil;
    };
    if (!isNil "BO_fmMapCloseEH") then {
        removeMissionEventHandler ["Map", BO_fmMapCloseEH];
        BO_fmMapCloseEH = nil;
    };
    openMap false;

    private _mortar = missionNamespace getVariable ["BO_fmMortar", objNull];
    private _shell  = missionNamespace getVariable ["BO_fmShellType", ""];
    private _count  = missionNamespace getVariable ["BO_fmCount", 0];
    if (isNull _mortar || {_shell isEqualTo ""} || {_count <= 0}) exitWith {};

    private _prices = createHashMap;
    _prices set ["HE",    500];
    _prices set ["SMOKE", 150];
    _prices set ["ILLUM", 100];
    private _cost = (_prices getOrDefault [_shell, 500]) * _count;
    private _costFmt = [_cost, 1, 0, true] call CBA_fnc_formatNumber;

    private _opts = [];
    private _header = format ["<t align='center' size='1.1'>Confirm Fire Mission</t><br/><t align='center' size='0.85'>%1 x %2 @ grid %3</t><br/><t align='center' size='0.85'>Cost: $%4 (bank)</t>",
        _count, _shell, mapGridPosition _pos, _costFmt];
    _opts pushBack _header;
    _opts pushBack [
        "Confirm",
        {
            params ["_mortar", "_shell", "_count", "_pos"];
            [_mortar, _shell, _count, _pos, getPlayerUID player] remoteExec ["BO_fnc_callFireMission", 2, false];
        },
        [_mortar, _shell, _count, _pos]
    ];
    _opts pushBack ["Cancel", {}];
    _opts call OT_fnc_playerDecision;
}];

// Cleanup on map close (ESC). Without this, the MapSingleClick EH
// leaks and the next stray map click anywhere triggers the artillery
// confirm dialog using the stale BO_fm* missionNamespace values.
BO_fmMapCloseEH = addMissionEventHandler ["Map", {
    params ["_mapIsOpened"];
    if (_mapIsOpened) exitWith {};
    if (!isNil "BO_fmMapClickEH") then {
        removeMissionEventHandler ["MapSingleClick", BO_fmMapClickEH];
        BO_fmMapClickEH = nil;
    };
    if (!isNil "BO_fmMapCloseEH") then {
        removeMissionEventHandler ["Map", BO_fmMapCloseEH];
        BO_fmMapCloseEH = nil;
    };
}];
