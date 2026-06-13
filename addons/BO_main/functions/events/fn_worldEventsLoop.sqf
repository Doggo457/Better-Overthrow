#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_worldEventsLoop
 *
 * Server-only. Installs a CBA per-frame handler at a 60s real-time
 * cadence. Each tick:
 *
 *   1. Sweeps BO_activeWorldEvents and prunes any entries whose
 *      _endDate has passed. Tears down the corresponding badge
 *      markers and emits an "Event expired" audit row per expiry.
 *
 *   2. Detects in-game midnight (hour 0 with a fresh _day vs.
 *      BO_eventLastMidnight) and fires BO_fnc_worldEventsTick to
 *      pick the day's events. Updates BO_eventLastMidnight before
 *      the tick to avoid double-firing if the PFH runs twice
 *      inside the same in-game hour.
 *
 * The handle is stashed in BO_eventLoopHandle. If a loop is already
 * installed (e.g. preInit re-fired after a load), the old handle is
 * removed before re-install to stay idempotent.
 *
 * Master toggle: missionNamespace var bo_events_enabled_cached. If
 * disabled, the loop is never installed; expiry/badges still ride
 * on whatever the existing list contains at toggle-off time, but
 * nothing new fires.
 */

SERVER_ONLY;

if (!(missionNamespace getVariable ["bo_events_enabled_cached", true])) exitWith {
    BO_LOG_INFO("events", "world demand events disabled by mission param");
};

if (!isNil "BO_eventLoopHandle") then {
    [BO_eventLoopHandle] call CBA_fnc_removePerFrameHandler;
    BO_eventLoopHandle = nil;
};

BO_eventLoopHandle = [{
    // ---- expiry prune ----
    private _active = server getVariable ["BO_activeWorldEvents", []];
    if (_active isNotEqualTo []) then {
        private _kept = [];
        private _nowNum = dateToNumber date;
        {
            _x params [
                ["_town", "", [""]],
                ["_type", "", [""]],
                ["_startDate", [], [[]]],
                ["_endDate", [], [[]]],
                ["_items", [], [[]]],
                ["_mul", 1, [0]],
                ["_eid", "", [""]]
            ];
            if (_endDate isEqualTo []) then {
                _kept pushBack _x;
            } else {
                if ((dateToNumber _endDate) > _nowNum) then {
                    _kept pushBack _x;
                } else {
                    private _mk = format ["bo_evt_%1", _eid];
                    deleteMarker _mk;
                    private _desc = format ["Event expired: %1 in %2", _type, _town];
                    [AUDIT_EVENTS, _desc, [_eid, _town, _type], "", ""] call BO_fnc_auditServer;
                    private _lmsg = format ["world event expired eid=%1 town=%2 type=%3", _eid, _town, _type];
                    BO_LOG_INFO("events", _lmsg);
                };
            };
        } forEach _active;
        if (count _kept != count _active) then {
            server setVariable ["BO_activeWorldEvents", _kept, true];
        };
    };

    // ---- midnight pick ----
    // Detect a new day via the day-of-month delta alone. The earlier
    // `_hour == 0` gate missed midnights crossed by skipTime fast-
    // forwards (OT_fnc_sleep), since the PFH may not sample any frame
    // during in-game hour 0. Using a day delta fires once per new day
    // regardless of when the PFH next ticks.
    private _day = date select 2;
    private _last = server getVariable ["BO_eventLastMidnight", -1];
    if (_day != _last && {_last >= 0 || {time > 60}}) then {
        server setVariable ["BO_eventLastMidnight", _day, true];
        [] call BO_fnc_worldEventsTick;
    } else {
        if (_last < 0) then {
            // First tick after server boot -- prime the stamp so we
            // don't double-fire on the very next day rollover.
            server setVariable ["BO_eventLastMidnight", _day, true];
        };
    };
}, 60, []] call CBA_fnc_addPerFrameHandler;

private _msg = format ["worldEventsLoop installed (handle=%1)", BO_eventLoopHandle];
BO_LOG_INFO("events", _msg);
