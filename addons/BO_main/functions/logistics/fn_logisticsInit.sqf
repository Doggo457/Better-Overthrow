#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsInit
 *
 * Server postInit -- hydrate logistics state and install the
 * scheduler tick.
 *
 * State:
 *   BO_logisticsRoutes              (server var, FIFO array)
 *   BO_logisticsActiveDeliveries    (server var, in-flight payloads)
 *
 * Both auto-saved by OT's saveGame namespace scan.
 *
 * Tick (every `bo_logistics_tick_seconds` seconds, default 10):
 *   1. For each unpaused route:
 *        - Resolve schedule trigger (Manual never; Interval by
 *          elapsed time since lastFired; TimeOfDay by in-game clock
 *          match with 120 s dedup so a 6-tick spanning minute fires
 *          only once).
 *        - On trigger, call BO_fnc_logisticsDispatch. On "ok",
 *          advance lastFired and increment success stat. On failure,
 *          stamp the failure reason; on container_missing failures,
 *          auto-pause the route so the player notices.
 *   2. For each active delivery whose etaTime has elapsed, call
 *      BO_fnc_logisticsArrive and remove it from the active list.
 *
 * Idempotent via BO_logisticsInitDone (so server-side scripts that
 * re-run postInit on reload don't double-install the PFH).
 */

if (!isServer) exitWith {};
if (missionNamespace getVariable ["BO_logisticsInitDone", false]) exitWith {};
missionNamespace setVariable ["BO_logisticsInitDone", true];

if (isNil { server getVariable "BO_logisticsRoutes" }) then {
    server setVariable ["BO_logisticsRoutes", [], true];
};
if (isNil { server getVariable "BO_logisticsActiveDeliveries" }) then {
    server setVariable ["BO_logisticsActiveDeliveries", [], true];
};

private _tickSec = missionNamespace getVariable ["bo_logistics_tick_seconds", 10];

[{
    if !(missionNamespace getVariable ["bo_logistics_enabled", true]) exitWith {};

    private _now = serverTime;
    private _today = date;
    private _hh = _today select 3;
    private _mm = _today select 4;

    // Routes pass.
    private _routes = server getVariable ["BO_logisticsRoutes", []];
    private _dirty = false;

    {
        if (_x select 8) then { continue }; // paused

        _x params [
            "_routeId", "_ownerUID", "_srcId", "_dstId",
            "_items", "_qtyPerTrip",
            "_schedule", "_fee", "_paused", "_stats", "_skipIfEmpty"
        ];
        _schedule params [["_mode", "MANUAL"], ["_intervalMin", 60], ["_timeOfDay", [0, 0]], ["_lastFired", 0]];

        // Reload guard: serverTime is session-relative and resets near 0 each
        // mission load. A saved _lastFired from a longer prior session looks
        // like the future from this session's clock, so (_now - _lastFired)
        // goes negative and the route stalls for hours. Clamp stale stamps
        // back to 0 so the next interval check evaluates sanely.
        if (_lastFired > _now) then {
            _lastFired = 0;
            _schedule set [3, 0];
            _x set [6, _schedule];
            _dirty = true;
        };

        private _due = false;
        switch (_mode) do {
            case "INTERVAL": {
                _due = (_intervalMin > 0) && ((_now - _lastFired) >= (_intervalMin * 60));
            };
            case "TIMEOFDAY": {
                _timeOfDay params [["_th", 0], ["_tm", 0]];
                _due = (_hh isEqualTo _th) && (_mm isEqualTo _tm) && ((_now - _lastFired) >= 120);
            };
            default {};
        };

        if (_due) then {
            private _result = [_x] call BO_fnc_logisticsDispatch;
            if (_result isEqualTo "ok") then {
                _schedule set [3, _now];
                _x set [6, _schedule];
                _stats set [0, (_stats param [0, 0]) + 1];
                _stats set [1, _now];
                _stats set [2, ""];
                _x set [9, _stats];
                _dirty = true;
            } else {
                _stats set [2, _result];
                _x set [9, _stats];
                _dirty = true;
                if (_result in ["src_missing", "dst_missing"]) then {
                    _x set [8, true];
                };
            };
        };
    } forEach _routes;

    if (_dirty) then {
        server setVariable ["BO_logisticsRoutes", _routes, true];
    };

    // Active deliveries pass.
    private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];

    // First post-load tick: rebase any delivery whose absolute serverTime
    // ETA is far in the future relative to the current session clock.
    // serverTime resets near 0 each mission load, so a saved ETA from a
    // prior session would otherwise sit "in the future" for hours until
    // the new clock catches up. Preserve remaining travel time by
    // anchoring eta to now + (savedEta - savedStart).
    if !(missionNamespace getVariable ["BO_logisticsETARebased", false]) then {
        {
            private _savedStart = _x select 2;
            private _savedEta   = _x select 3;
            // Stale detector: a dispatch START in the future is impossible
            // within a session, so any entry whose start exceeds the current
            // clock was saved under a prior session's (longer) serverTime.
            // (The old 24h ETA margin could never trigger -- real ETAs are
            // minutes out, so stale entries silently stalled for roughly the
            // prior session's uptime while the clamped route re-dispatched
            // duplicates.) Preserve remaining travel by re-anchoring to now.
            if (_savedStart > _now) then {
                private _remainingTravel = (_savedEta - _savedStart) max 0;
                _x set [2, _now];
                _x set [3, _now + _remainingTravel];
            };
        } forEach _deliveries;
        server setVariable ["BO_logisticsActiveDeliveries", _deliveries, true];
        missionNamespace setVariable ["BO_logisticsETARebased", true];
    };

    private _remaining = [];
    {
        if (_now >= (_x select 3)) then {
            [_x] call BO_fnc_logisticsArrive;
        } else {
            _remaining pushBack _x;
        };
    } forEach _deliveries;

    if (count _remaining isNotEqualTo count _deliveries) then {
        server setVariable ["BO_logisticsActiveDeliveries", _remaining, true];
    };
}, _tickSec] call CBA_fnc_addPerFrameHandler;

BO_LOG_INFO("logistics", "Scheduler installed");
