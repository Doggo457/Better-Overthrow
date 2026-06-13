#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_exportAudit
 *
 * Build a filtered snapshot of the audit log for export to clipboard
 * or for the in-game viewer. Returns entries matching the filter,
 * sorted newest-first.
 *
 * Params:
 *   0: ARRAY  - categories to include  (empty = all)
 *   1: STRING - actor UID filter        (empty = all)
 *   2: SCALAR - max age in real seconds (0 = no age limit)
 *   3: SCALAR - max entries to return   (default 500)
 *
 * Returns: ARRAY of entries (each entry is the tuple from auditServer).
 */

if (!isServer) exitWith { [] };

params [
    ["_categories", [], [[]]],
    ["_actorUID", "", [""]],
    ["_maxAge", 0, [0]],
    ["_maxEntries", 500, [0]]
];

private _log = server getVariable ["BO_auditLog", createHashMap];
// Age filter uses real-world wall clock via dateToNumber: tickTime
// resets to 0 at mission start, so pre-reload entries with high tick
// values would have been treated as "ancient" or (worse, post-restart)
// "recent". dateToNumber preserves ordering across save/reload.
// _maxAge is interpreted as max-age in dateToNumber units (fractional
// years), which is the same currency the entries are stamped in.
private _nowNum = dateToNumber date;

// Gather candidate categories.
private _bucketKeys = if (_categories isEqualTo []) then {
    keys _log
} else {
    _categories
};

// Collect entries that pass the filter.
private _result = [];
{
    private _bucket = _log getOrDefault [_x, []];
    {
        private _entry = _x;
        _entry params ["_date", "", "_uid"];

        private _passes = true;
        if (_actorUID isNotEqualTo "" && {_uid isNotEqualTo _actorUID}) then { _passes = false };
        if (_passes && _maxAge > 0 && {(_nowNum - (dateToNumber _date)) > _maxAge}) then { _passes = false };

        if (_passes) then { _result pushBack _entry };
    } forEach _bucket;
} forEach _bucketKeys;

// Sort newest-first by entry date (dateToNumber). Drop the redundant
// `_result sort false` -- it would have sorted lexically by the date
// array's stringification, then BIS_fnc_sortBy re-orders anyway, so
// the first sort was pure waste (and noisy if entries had equal keys).
private _sortedByTick = [_result, [], { dateToNumber (_x select 0) }, "DESCEND"] call BIS_fnc_sortBy;

// Trim to max.
if (count _sortedByTick > _maxEntries) then {
    _sortedByTick resize _maxEntries;
};

_sortedByTick;
