#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logMissionDebrisInit
 *
 * Server-side postInit: install the periodic sweep that decides when
 * to despawn entries registered via BO_fnc_logMissionDebris.
 *
 * Logic per entry:
 *   - If any object in the entry has a player within 300m, reset
 *     the despawn timer to (now + delay). Keeps the debris around
 *     for another full hour.
 *   - When `serverTime >= despawnAt`, every object in the entry is
 *     deleted and the entry is removed from the registry.
 *   - If all the entry's objects are already null (already cleaned
 *     up some other way), drop the entry.
 *
 * 60s sweep interval is plenty -- the timer is on the hour scale.
 *
 * Idempotent via BO_logMissionDebrisInit flag.
 */

if (!isServer) exitWith {};
if (missionNamespace getVariable ["BO_logMissionDebrisInit", false]) exitWith {};
missionNamespace setVariable ["BO_logMissionDebrisInit", true];

if (isNil { server getVariable "BO_missionDebris" }) then {
    server setVariable ["BO_missionDebris", [], true];
};

[{
    private _registry = server getVariable ["BO_missionDebris", []];
    if (_registry isEqualTo []) exitWith {};

    private _now = serverTime;
    private _keep = [];
    {
        // Defaulting params keeps us backward-compatible with legacy 2-tuples already in the registry.
        _x params [["_objects", []], ["_despawnAt", 0], ["_delaySec", 3600]];

        // Drop already-null entries
        private _live = _objects select { !isNull _x };
        if (_live isEqualTo []) then { continue };

        // Player proximity check -- any object < 300m from any
        // player resets the timer.
        private _anyNearby = false;
        {
            private _o = _x;
            private _pos = getPosATL _o;
            if (_pos isEqualTo [0,0,0]) then { _pos = getPos _o };
            {
                if (alive _x && {(_x distance2D _pos) < 300}) exitWith { _anyNearby = true };
            } forEach allPlayers;
            if (_anyNearby) exitWith {};
        } forEach _live;

        if (_anyNearby) then {
            // Honor the caller-registered delay rather than slamming back to 1hr.
            _despawnAt = _now + _delaySec;
            _keep pushBack [_live, _despawnAt, _delaySec];
        } else {
            if (_now >= _despawnAt) then {
                { deleteVehicle _x } forEach _live;
            } else {
                _keep pushBack [_live, _despawnAt, _delaySec];
            };
        };
    } forEach _registry;

    server setVariable ["BO_missionDebris", _keep, true];
}, 60] call CBA_fnc_addPerFrameHandler;

BO_LOG_INFO("admin", "mission debris despawn sweep installed (60s interval, 1hr inactivity threshold)");
