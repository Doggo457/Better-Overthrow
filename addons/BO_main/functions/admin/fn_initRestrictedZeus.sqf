#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initRestrictedZeus
 *
 * Multi-user Zeus bookkeeping (the name is historical -- this now
 * maintains BOTH tiers). Curators themselves are created on demand,
 * one per (player UID, tier), by BO_fnc_acquireZeus; assignment goes
 * through BO_fnc_zeusAssign/zeusRelease with server-side privilege
 * checks. This init installs the two maintenance handlers:
 *
 *   EntityCreated      -- keeps every registry curator's editable pool
 *                         current (independent units for restricted
 *                         seats, everything for full seats).
 *   PlayerDisconnected -- frees the leaver's seat so the module isn't
 *                         left assigned to a null player (re-login
 *                         would otherwise find a dead seat).
 *
 * Idempotent. Safe to call multiple times.
 */

SERVER_ONLY;

if (missionNamespace getVariable ["BO_zeusRegistryInit", false]) exitWith {
    BO_LOG_INFO("admin","Zeus registry already initialized");
};
missionNamespace setVariable ["BO_zeusRegistryInit", true];

if (isNil "BO_zeusRegistry") then { BO_zeusRegistry = [] };

addMissionEventHandler ["EntityCreated", {
    params ["_entity"];
    if (isNull _entity) exitWith {};
    if (!(_entity isKindOf "AllVehicles")) exitWith {};
    private _isIndep = side _entity isEqualTo independent;
    {
        _x params ["_uid", "_tier", "_cur"];
        if (!isNull _cur) then {
            if (_tier isEqualTo "full" || {_isIndep}) then {
                _cur addCuratorEditableObjects [[_entity], true];
            };
        };
    } forEach (missionNamespace getVariable ["BO_zeusRegistry", []]);
}];

addMissionEventHandler ["PlayerDisconnected", {
    params ["_id", "_uid", "_name"];
    {
        _x params ["_curUid", "_tier", "_cur"];
        if (_curUid isEqualTo _uid && {!isNull _cur}) then {
            if (!isNull (getAssignedCuratorUnit _cur)) then {
                unassignCurator _cur;
            };
        };
    } forEach (missionNamespace getVariable ["BO_zeusRegistry", []]);
}];

BO_LOG_INFO("admin","Zeus registry initialized (per-player curators, both tiers)");
[AUDIT_ADMIN, "Zeus registry initialized (per-player curators)", nil, "", ""] call BO_fnc_auditServer;
