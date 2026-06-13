#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_recordMetric
 *
 * Record a performance measurement to the rolling metrics window.
 * Used by HAL, logistics rule eval, factory production tick, etc.
 *
 * Metrics are RUNTIME ONLY — not saved with the rest of state
 * because they'd be stale after a load. Use BO_fnc_audit for events
 * that should persist.
 *
 * Each metric category keeps a rolling window of the last 100
 * measurements as [tickTime, duration] pairs. Older entries get
 * trimmed.
 *
 * Params:
 *   0: STRING - subsystem ("hal" / "logistics" / "factory" / etc.)
 *   1: SCALAR - duration in seconds
 *   2: SCALAR - optional secondary metric (count of items processed)
 *
 * Returns: nothing.
 */

if (!isServer) exitWith {};

// Allow disabling metrics entirely via mission param for cheap servers.
if (!(missionNamespace getVariable ["BO_perfMetrics", true])) exitWith {};

params [
    ["_subsystem", "general", [""]],
    ["_duration", 0, [0]],
    ["_secondary", 0, [0]]
];

private _store = missionNamespace getVariable ["BO_perfStore", createHashMap];
private _window = _store getOrDefault [_subsystem, []];
_window pushBack [diag_tickTime, _duration, _secondary];

// Rolling window of 100 samples. Trimming from the front keeps
// the array references stable for any concurrent reader.
if (count _window > 100) then {
    _window deleteAt 0;
};

_store set [_subsystem, _window];
missionNamespace setVariable ["BO_perfStore", _store];
