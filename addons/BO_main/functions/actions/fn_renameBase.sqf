#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_renameBase
 *
 * Server-authoritative rename of a registered base. Walks the
 * `bases` array on the OT `server` namespace, finds the entry whose
 * slot 0 matches _baseObj, mutates slot 1 in place, and broadcasts.
 *
 * Slot 0 in a `bases` entry can be either the flag object (newer
 * code path) or a position vector (OT legacy). We accept either by
 * trying an object-identity match first, then falling back to a
 * 2D position match within 1m if the caller passed a flag object
 * but the stored entry is keyed by position.
 *
 * Intended call site:
 *   [_flag, "New Name"] remoteExec ["BO_fnc_renameBase", 2, false];
 *
 * Params:
 *   0: OBJECT - the flag object identifying the base
 *   1: STRING - new display name
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [
    ["_baseObj", objNull, [objNull]],
    ["_newName", "", [""]]
];

if (isNull _baseObj) exitWith {};
if (_newName isEqualTo "") exitWith {};

private _bases = server getVariable ["bases", []];
private _idx = _bases findIf { (_x select 0) isEqualTo _baseObj };

if (_idx < 0) then {
    // Fallback: slot 0 may be a position rather than the flag obj.
    private _basePos = getPosASL _baseObj;
    _basePos set [2, 0];
    _idx = _bases findIf {
        private _slot0 = _x select 0;
        (_slot0 isEqualType []) && { (_slot0 distance2D _basePos) < 1 }
    };
};

if (_idx < 0) exitWith {
    private _msg = format ["renameBase: no matching entry for %1", _baseObj];
    BO_LOG_WARN("admin", _msg);
};

private _entry = _bases select _idx;
private _oldName = _entry param [1, ""];
_entry set [1, _newName];
_bases set [_idx, _entry];
server setVariable ["bases", _bases, true];

// Keep the flag's local "name" var in sync so clients reading via
// getVariable "name" see the new label without round-tripping.
_baseObj setVariable ["name", _newName, true];

[AUDIT_ADMIN,
 format ["renameBase: '%1' -> '%2'", _oldName, _newName],
 [_oldName, _newName, _baseObj],
 "",
 ""
] call BO_fnc_auditServer;
