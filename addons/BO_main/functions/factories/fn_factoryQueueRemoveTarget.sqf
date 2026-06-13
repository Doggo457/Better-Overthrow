#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryQueueRemoveTarget
 *
 * Server-auth: remove the queue entry at _idx from _factory's
 * BO_queue. Bounds-checks _idx; no-op if out of range.
 *
 * Params:
 *   0: OBJECT - factory
 *   1: SCALAR - index to remove
 */

SERVER_ONLY;

params [
    ["_factory", objNull, [objNull]],
    ["_idx", -1, [0]]
];
if (isNull _factory) exitWith {};

private _queue = _factory getVariable ["BO_queue", []];
if (_idx < 0 || _idx >= count _queue) exitWith {};

_queue deleteAt _idx;
_factory setVariable ["BO_queue", _queue, true];
