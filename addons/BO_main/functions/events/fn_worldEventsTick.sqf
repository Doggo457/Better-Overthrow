#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_worldEventsTick
 *
 * Server-only. Runs once at the in-game midnight rollover (the loop
 * gates entry by hour=0 + day change). Picks up to
 * bo_events_per_day_cached town candidates and assigns each a weighted
 * event from BO_eventCatalog.
 *
 *   1. Build candidate town list: OT_allTowns minus towns that already
 *      have an active event (one event per town max).
 *
 *   2. For each pick slot, sample a random candidate, build the
 *      per-town eligible event list by intersecting BO_eventCatalog
 *      filters, weight by spec._weight, and selectRandom.
 *
 *   3. Compute end-date via BIS_fnc_addDaytime so month/year rollover
 *      is correct.
 *
 *   4. Spawn a global yellow badge marker (server-side createMarker is
 *      broadcast to JIP clients automatically) at the town center.
 *
 *   5. Broadcast a notifyMinor and emit an "Event started" audit row.
 *
 * Multiplier is randomized inside the spec's [lo, hi] range then
 * clamped to bo_event_multiplier_max_cached / 100.
 */

SERVER_ONLY;

if (isNil "BO_eventCatalog" || {BO_eventCatalog isEqualTo []}) exitWith {
    BO_LOG_WARN("events", "worldEventsTick called with empty catalog");
};

private _perDay = missionNamespace getVariable ["bo_events_per_day_cached", 3];
private _durationDays = missionNamespace getVariable ["bo_event_duration_days_cached", 2];
private _mulCap = (missionNamespace getVariable ["bo_event_multiplier_max_cached", 200]) / 100;
if (_mulCap < 1) then { _mulCap = 1 };

private _active = server getVariable ["BO_activeWorldEvents", []];
private _busyTowns = _active apply { _x select 0 };
private _candidates = OT_allTowns select { !(_x in _busyTowns) };
if (_candidates isEqualTo []) exitWith {
    BO_LOG_INFO("events", "worldEventsTick: no candidate towns (all busy)");
};

private _picksWanted = _perDay min (count _candidates);
private _picksMade = 0;
private _spawned = [];

while { _picksMade < _picksWanted && {_candidates isNotEqualTo []} } do {
    private _town = selectRandom _candidates;
    _candidates = _candidates - [_town];

    // Build weighted eligible pool: for each catalog row whose filter
    // accepts _town, pushBack _weight copies so selectRandom samples
    // proportionally.
    private _eligible = [];
    {
        _x params [
            ["_type", "", [""]],
            ["_dname", "", [""]],
            ["_items", [], [[]]],
            ["_mulRng", [1,1], [[]]],
            ["_filter", { true }, [{}]],
            ["_weight", 1, [0]],
            ["_shopHint", "", [""]]
        ];
        if ([_town] call _filter) then {
            for "_i" from 1 to _weight do {
                _eligible pushBack _x;
            };
        };
    } forEach BO_eventCatalog;

    if (_eligible isEqualTo []) then {
        // No eligible event type for this town -- skip to next candidate.
        // Don't consume a pick slot since we picked nothing.
    } else {
        private _spec = selectRandom _eligible;
        _spec params [
            ["_type", "", [""]],
            ["_dname", "", [""]],
            ["_items", [], [[]]],
            ["_mulRng", [1,1], [[]]],
            ["_eligibleFn", { true }, [{}]],
            ["_weight", 1, [0]],
            ["_shopHint", "", [""]]
        ];
        _mulRng params [["_lo", 1, [0]], ["_hi", 1, [0]]];
        private _mul = _lo + (random (_hi - _lo));
        if (_mul > _mulCap) then { _mul = _mulCap };
        // Round to 1 decimal place for display.
        _mul = (round (_mul * 10)) / 10;

        private _start = +date;
        private _end = [_start, _durationDays * 24] call BIS_fnc_addDaytime;
        // BIS_fnc_addDaytime returns the same arity as the input. We
        // always feed a 5-element [Y,M,D,H,Mn] so _end is 5-element
        // too. Belt-and-braces guard for any future change.
        if (count _end < 5) then {
            for "_i" from (count _end) to 4 do { _end pushBack 0 };
        };

        private _eid = format ["evt_%1_%2", round diag_tickTime, _picksMade];
        private _entry = [_town, _type, _start, _end, _items, _mul, _eid];
        _spawned pushBack _entry;
        _picksMade = _picksMade + 1;

        // Badge marker overlay. createMarker is broadcast globally.
        private _posTown = server getVariable _town;
        if (!isNil "_posTown") then {
            private _mkName = format ["bo_evt_%1", _eid];
            // Idempotent: clear any stale marker with this name first.
            deleteMarker _mkName;
            createMarker [_mkName, _posTown];
            _mkName setMarkerType "ot_Shop";
            _mkName setMarkerSize [0.6, 0.6];
            _mkName setMarkerColor "ColorYellow";
            _mkName setMarkerText (format ["!%1", _dname]);
        };

        // Broadcast notification to everyone.
        private _notif = format ["%1: %2 -- sellers favor %3 (x%4)",
            _town, _dname, _shopHint, _mul];
        _notif remoteExec ["OT_fnc_notifyMinor", 0, false];

        // Audit.
        private _adesc = format ["Event started: %1 in %2 (x%3)", _type, _town, _mul];
        [AUDIT_EVENTS, _adesc, [_eid, _town, _type, _items, _mul], "", ""] call BO_fnc_auditServer;
    };
};

if (_spawned isNotEqualTo []) then {
    _active append _spawned;
    server setVariable ["BO_activeWorldEvents", _active, true];
};

private _msg = format ["worldEventsTick: spawned %1 event(s)", count _spawned];
BO_LOG_INFO("events", _msg);
