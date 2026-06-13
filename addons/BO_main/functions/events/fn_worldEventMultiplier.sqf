#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_worldEventMultiplier
 *
 * Pure lookup. Given (_town, _cls), returns the maximum active demand
 * multiplier (>= 1.0) that applies to _cls in _town. Returns 1 if no
 * event matches.
 *
 * Boosted item tokens can be either:
 *   - "@<bucket>" : resolves to BO_eventItemBuckets get token
 *   - "<classname>" : direct classname compare
 *
 * Multiple events at the same town are not produced by the picker
 * (one-event-per-town invariant) but the hook iterates them all and
 * picks the max multiplier just in case migration leaves stacked rows.
 *
 *   params: [_town:STRING, _cls:STRING]
 *   return: NUMBER
 */

params [
    ["_town", "", [""]],
    ["_cls", "", [""]]
];

if (_town isEqualTo "" || {_cls isEqualTo ""}) exitWith { 1 };

private _active = server getVariable ["BO_activeWorldEvents", []];
if (_active isEqualTo []) exitWith { 1 };

private _buckets = if (isNil "BO_eventItemBuckets") then { createHashMap } else { BO_eventItemBuckets };

private _mul = 1;
{
    _x params [
        ["_evtTown", "", [""]],
        ["_eType",   "", [""]],
        ["_eStart",  [], [[]]],
        ["_eEnd",    [], [[]]],
        ["_items",   [], [[]]],
        ["_eMul",    1,  [0]]
    ];
    if (_evtTown isEqualTo _town) then {
        private _matched = false;
        {
            private _tok = _x;
            if ((_tok select [0, 1]) isEqualTo "@") then {
                private _bucket = _buckets getOrDefault [_tok, []];
                if (_cls in _bucket) exitWith { _matched = true };
            } else {
                if (_tok isEqualTo _cls) exitWith { _matched = true };
            };
        } forEach _items;
        if (_matched && {_eMul > _mul}) then { _mul = _eMul };
    };
} forEach _active;

_mul
