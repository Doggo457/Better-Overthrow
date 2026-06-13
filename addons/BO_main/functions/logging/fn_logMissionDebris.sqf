#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logMissionDebris
 *
 * Register a batch of objects (props, vehicles, buildings, corpses
 * by reference) for delayed despawn. Persistence rule per user
 * spec: keep the debris in the world as long as ANY player has
 * been within 300m within the last hour. Only despawn after a full
 * hour with zero player presence in range.
 *
 * The world keeps wrecked checkpoints, dead patrols, looted depots
 * for long enough that they feel like the player's actual marks
 * on the world, not popped-out-of-existence script artifacts.
 *
 * Despawn sweep runs every 60s via BO_fnc_logMissionDebrisInit.
 *
 * Params:
 *   0: ARRAY  - objects/groups to track. Groups have their units
 *               unpacked automatically.
 *   1: NUMBER - optional override of the despawn delay in seconds
 *               (default 3600 / 1hr). Pass shorter for cleanup of
 *               failed-mission tearing-down state.
 */

// MP routing: registry lives on server; clients must remoteExec so dedicated MP doesn't silently lose every mission's debris.
if (!isServer) exitWith { _this remoteExec ["BO_fnc_logMissionDebris", 2] };

params [["_objects", [], [[]]], ["_delaySec", 3600, [0]]];
if (_objects isEqualTo []) exitWith {};

// Unpack groups -> units, drop nulls, dedupe.
// pushBackUnique matches the docstring's "dedupe" claim -- prevents
// double-tracking when a caller passes both a group AND a unit that
// belongs to it (e.g. protectDefector's [_civGrp, _defector]).
private _flat = [];
{
    if (_x isEqualType grpNull) then {
        { _flat pushBackUnique _x } forEach (units _x);
    } else {
        if (!isNull _x) then { _flat pushBackUnique _x };
    };
} forEach _objects;
if (_flat isEqualTo []) exitWith {};

private _registry = server getVariable ["BO_missionDebris", []];
// Persist _delaySec so proximity ticks can re-extend by the original window rather than a hardcoded 1hr.
_registry pushBack [_flat, serverTime + _delaySec, _delaySec];
server setVariable ["BO_missionDebris", _registry, true];

private _msg = format ["debris registered: %1 objects, despawn timer %2s", count _flat, _delaySec];
BO_LOG_INFO("admin", _msg);
