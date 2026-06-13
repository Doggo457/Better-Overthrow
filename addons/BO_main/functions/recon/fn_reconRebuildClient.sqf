#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconRebuildClient
 *
 * Client-only. JIP / save-restore / respawn entry point. Tears down any
 * local reveal state this client currently holds (defensive: protects
 * against double-arms) then walks server's BO_activeRecon and re-arms
 * each entry that
 *   (a) belongs to this player, and
 *   (b) hasn't expired yet.
 *
 * Markers are local-only (engine semantics: createMarkerLocal does NOT
 * survive a load), so this function is what makes "I bought recon,
 * saved, reloaded" still show markers for the remaining duration.
 */

if (!hasInterface) exitWith {};

private _uid = getPlayerUID player;
if (_uid isEqualTo "") exitWith {};

// Tear down any local state -- defensive in case this fires twice.
{
    _x params ["_scope", "_key", "_expire", "_markers", "_pfh", "_txt"];
    { deleteMarkerLocal _x } forEach _markers;
    if (!isNull _txt) then { ctrlDelete _txt };
    [_pfh] call CBA_fnc_removePerFrameHandler;
} forEach (missionNamespace getVariable ["BO_reconClientActive", []]);
missionNamespace setVariable ["BO_reconClientActive", []];

private _active = server getVariable ["BO_activeRecon", []];

{
    _x params ["_ownerUID", "_scope", "_scopeKey", "_expire"];
    if (_ownerUID isEqualTo _uid && {_expire > serverTime}) then {
        [_scope, _scopeKey, _expire] call BO_fnc_reconClientArm;
    };
} forEach _active;
