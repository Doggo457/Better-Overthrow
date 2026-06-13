#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryQueueAddTarget
 *
 * Server-auth queue mutation for a specific factory object.
 * Coalesces ADD with the tail entry if it has the same classname
 * (matches the old single-factory flow). Sets BO_producing if the
 * queue was empty so the next tick starts producing immediately.
 *
 * Params:
 *   0: OBJECT - factory
 *   1: STRING - classname to add
 *   2: SCALAR - qty (must be > 0)
 */

SERVER_ONLY;

params [
    ["_factory", objNull, [objNull]],
    ["_cls", "", [""]],
    ["_qty", 0, [0]]
];
if (isNull _factory) exitWith {};
if (_cls isEqualTo "" || _qty <= 0) exitWith {};

private _queue = _factory getVariable ["BO_queue", []];
private _queueItem = [_cls, 0];
private _doAdd = true;

if (_queue isNotEqualTo []) then {
    private _tail = _queue select -1;
    if ((_tail select 0) isEqualTo _cls) then {
        _queueItem = _tail;
        _doAdd = false;
    };
} else {
    if ((_factory getVariable ["BO_producing", ""]) isEqualTo "") then {
        _factory setVariable ["BO_producing", _cls, true];
    };
};

_queueItem set [1, (_queueItem select 1) + _qty];

if (_doAdd) then {
    _queue pushBack _queueItem;
};

_factory setVariable ["BO_queue", _queue, true];
