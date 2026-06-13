#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_applySabotageEffect
 *
 * Apply one of three sabotage effects to a named NATO base.
 *
 *   vehicle_fire       Damage a parked vehicle in the spawn radius.
 *                      Fallback if none spawned: drain the
 *                      vehgarrison<base> type list by one so the
 *                      next NATO spawn is denied.
 *   supply_theft       Subtract BO_sabotageSupplyDrain from
 *                      NATOresources (default 50).
 *   garrison_desertion Drop garrison<base> by 1..3; if in spawn
 *                      distance, delete the same count of lowest-rank
 *                      live NATO men near the base.
 *
 * Server-only.
 *
 * Params:
 *   0: STRING - base name (matches OT marker / OT_objectiveData entry)
 *   1: ARRAY  - base world position
 *   2: STRING - effect tag ("vehicle_fire" | "supply_theft" | "garrison_desertion")
 */

if (!isServer) exitWith {};

params [["_baseName", "", [""]], ["_basePos", [0,0,0], [[]]], ["_effect", "", [""]]];
if (_baseName isEqualTo "" || {_effect isEqualTo ""}) exitWith {};

switch (_effect) do {
    case "vehicle_fire": {
        // Find a NATO-side spawned vehicle in the base's spawn radius.
        // "side _x isEqualTo east" (OT's NATO side) catches occupier
        // assets without false-positives on player vehicles which
        // default to civilian/independent.
        private _natoSide = blufor;
        private _live = nearestObjects [_basePos, ["AllVehicles"], 200, true] select {
            alive _x
            && {!(_x isKindOf "Man")}
            && {(side _x) isEqualTo _natoSide}
        };
        if (_live isNotEqualTo []) then {
            private _v = selectRandom _live;
            _v setDamage 1;
            private _msg = format ["Sabotage burned %1 at %2", typeOf _v, _baseName];
            [AUDIT_CIVILIAN, _msg, [_baseName, typeOf _v], "", ""] call BO_fnc_auditServer;
        } else {
            // Fallback: drain the vehgarrison type list. OT seeds this
            // per-base as the pool the next patrol spawn picks from;
            // removing one entry shrinks future spawns.
            private _vk = format ["vehgarrison%1", _baseName];
            private _vlist = server getVariable [_vk, []];
            if (count _vlist > 0) then {
                _vlist deleteAt (floor (random count _vlist));
                server setVariable [_vk, _vlist, true];
                private _msg = format ["Sabotage drained vehgarrison at %1 (-1)", _baseName];
                [AUDIT_CIVILIAN, _msg, [_baseName], "", ""] call BO_fnc_auditServer;
            } else {
                private _msg = format ["Sabotage vehicle_fire at %1 -- no live vehicles, empty vehgarrison", _baseName];
                BO_LOG_DEBUG("civilian", _msg);
            };
        };
    };
    case "supply_theft": {
        private _drain = missionNamespace getVariable ["BO_sabotageSupplyDrain", 50];
        private _r = server getVariable ["NATOresources", 2000];
        _r = (_r - _drain) max 0;
        server setVariable ["NATOresources", _r, true];
        private _msg = format ["Sabotage stole %1 NATO supplies at %2 (new %3)", _drain, _baseName, _r];
        [AUDIT_CIVILIAN, _msg, [_baseName, _drain, _r], "", ""] call BO_fnc_auditServer;
    };
    case "garrison_desertion": {
        private _gk = format ["garrison%1", _baseName];
        private _g = server getVariable [_gk, 0];
        if (_g <= 0) exitWith {
            private _msg = format ["Sabotage at %1: no garrison to desert", _baseName];
            BO_LOG_DEBUG("civilian", _msg);
        };
        private _drop = (1 + floor (random 3)) min _g;
        server setVariable [_gk, _g - _drop, true];

        if ([_basePos] call OT_fnc_inSpawnDistance) then {
            private _natoSide = blufor;
            private _natoMen = (nearestObjects [_basePos, ["Man"], 300, true]) select {
                alive _x
                && {(side _x) isEqualTo _natoSide}
                && {!isPlayer _x}
            };
            // ASCEND on rankId so we drop the weakest first.
            _natoMen = [_natoMen, [], { rankId _x }, "ASCEND"] call BIS_fnc_sortBy;
            private _toDelete = (_drop min count _natoMen);
            for "_i" from 0 to (_toDelete - 1) do {
                deleteVehicle (_natoMen select _i);
            };
        };

        private _msg = format ["Sabotage caused %1 desertions at %2", _drop, _baseName];
        [AUDIT_CIVILIAN, _msg, [_baseName, _drop], "", ""] call BO_fnc_auditServer;
    };
    default {
        private _msg = format ["applySabotageEffect: unknown effect '%1' at %2", _effect, _baseName];
        BO_LOG_WARN("civilian", _msg);
    };
};
