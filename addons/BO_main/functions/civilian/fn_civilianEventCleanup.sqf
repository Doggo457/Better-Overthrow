#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventCleanup
 *
 * Server-only single-event cleanup. Removes the registry slot,
 * deletes the NPC (and its group if empty), wipes markers on every
 * client. Idempotent: re-calling with the same eventId after the
 * slot is gone is a no-op.
 *
 * Params:
 *   0: STRING - event id (BO_civEvt_<N>)
 *   1: STRING - reason ("expired" | "killed" | "talked")
 */

if (!isServer) exitWith {};

params [["_eventId", "", [""]], ["_reason", "expired", [""]]];
if (_eventId isEqualTo "") exitWith {};

private _active = server getVariable ["BO_activeCivilianEvents", []];
private _idx = _active findIf { (_x select 0) isEqualTo _eventId };
if (_idx < 0) exitWith {};

private _entry = _active select _idx;
_entry params ["", "_town", "_npc", "", "_markerId"];

_active deleteAt _idx;
server setVariable ["BO_activeCivilianEvents", _active, true];

[_markerId] remoteExec ["BO_fnc_civilianEventMarkerRemove", 0, true];

if (!isNull _npc && {alive _npc}) then {
    private _grp = group _npc;
    deleteVehicle _npc;
    if (!isNull _grp && {units _grp isEqualTo []}) then {
        deleteGroup _grp;
    };
};

if (_reason isEqualTo "expired") then {
    private _msg = format ["%1: the informant has left town", _town];
    _msg remoteExec ["OT_fnc_notifyMinor", 0, false];
};

private _auditMsg = format ["Informant event %1 cleaned (%2)", _eventId, _reason];
[AUDIT_CIVILIAN, _auditMsg, [_town, _reason], "", ""] call BO_fnc_auditServer;
