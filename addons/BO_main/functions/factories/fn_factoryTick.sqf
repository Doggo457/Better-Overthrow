#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryTick
 *
 * Advance one production tick for _factory. Port of the GUERLoop
 * factory block (lines 255-427 in the legacy single-factory model),
 * scoped to one object so it scales linearly across N factories.
 *
 * Per-tick work, with all state on the factory object instead of
 * server-globals:
 *   1. If BO_producing doesn't match queue head, sync them (queue
 *      head wins -- the player switched what we should build).
 *   2. Compute time-to-produce and num-to-produce from the cost
 *      var on _currentCls. Bail out if cost data isn't registered.
 *   3. On the first tick of a new item (timespent == 0): ensure the
 *      output crate exists, check input materials + funds via
 *      OT_fnc_hasFromCargoContainers, consume them via
 *      OT_fnc_takeFromCargoContainers, accumulate timespent.
 *   4. On subsequent ticks: just accumulate timespent.
 *   5. On completion: pop the queue (or decrement qty), clear
 *      BO_producing, dispatch BO_fnc_factoryProduceOne to drop
 *      the output.
 *
 * Idempotent / safe to call on an idle factory (empty queue +
 * empty BO_producing returns immediately).
 *
 * The cargo-containers helpers (hasFromCargoContainers /
 * takeFromCargoContainers) take a position; we pass the factory's
 * position so they scan its surroundings (NOT OT_factoryPos).
 *
 * Server-only.
 *
 * Params:
 *   0: OBJECT - factory
 */

SERVER_ONLY;

params [["_factory", objNull, [objNull]]];
if (isNull _factory) exitWith {};
if (!alive _factory) exitWith {};
if (!(_factory getVariable ["BO_factoryEnabled", true])) exitWith {};

private _currentCls = _factory getVariable ["BO_producing", ""];
private _queue = _factory getVariable ["BO_queue", []];

// If queue head and producing disagree, prefer the queue. Mirrors
// GUERLoop:255-274 which clears producing if the head changed.
if (_currentCls isNotEqualTo "" && {_queue isNotEqualTo []}) then {
    private _item = _queue select 0;
    if ((_item select 0) isNotEqualTo _currentCls) then {
        _factory setVariable ["BO_producetime", 0, true];
        _factory setVariable ["BO_producing", _item select 0, true];
        _currentCls = _item select 0;
    };
};

// Seed from queue head if we're idle and there's something pending.
if (_currentCls isEqualTo "" && {_queue isNotEqualTo []}) then {
    _currentCls = (_queue select 0) select 0;
    _factory setVariable ["BO_producing", _currentCls, true];
    _factory setVariable ["BO_producetime", 0, true];
};

if (_currentCls isEqualTo "") exitWith {};

private _cost = cost getVariable [_currentCls, []];
if (_cost isEqualTo []) exitWith {};

_cost params ["_base", "_wood", "_steel", ["_plastic", 0]];

private _b = 1;
if (_base > 240)   then { _b = 10 };
if (_base > 10000) then { _b = 20 };
if (_base > 20000) then { _b = 30 };
if (_base > 50000) then { _b = 60 };

private _timetoproduce = _b + (round (_wood + 1)) + (round (_steel * 0.2)) + (round (_plastic * 5));
if (_timetoproduce > 120) then { _timetoproduce = 120 };
if (_timetoproduce < 5)   then { _timetoproduce = 5 };

private _timespent = _factory getVariable ["BO_producetime", 0];

private _numtoproduce = 1;
if (_wood < 1 && _wood > 0)       then { _numtoproduce = round (1 / _wood) };
if (_steel < 1 && _steel > 0)     then { _numtoproduce = round (1 / _steel) };
if (_plastic < 1 && _plastic > 0) then { _numtoproduce = round (1 / _plastic) };
private _costtoproduce = round ((_base * _numtoproduce) * 0.6);

if (_timespent isEqualTo 0) then {
    // First tick of a new item: pull resources from cargo containers
    // around THIS factory's position. The helper scans nearby
    // containers; we pass our factory position, not OT_factoryPos.
    private _factoryPos = getPosATL _factory;

    // Make sure the output crate exists so hasFromCargoContainers
    // can include it in the scan and takeFromCargoContainers has
    // somewhere to find the inputs the player just dumped in.
    [_factory] call BO_fnc_factoryEnsureOutputContainer;

    private _dowood    = ["OT_wood", _wood, _factoryPos] call OT_fnc_hasFromCargoContainers;
    private _dosteel   = ["OT_steel", _steel, _factoryPos] call OT_fnc_hasFromCargoContainers;
    private _doplastic = ["OT_plastic", _plastic, _factoryPos] call OT_fnc_hasFromCargoContainers;
    private _domoney   = ([] call OT_fnc_resistanceFunds >= _costtoproduce);

    if (_dowood && _dosteel && _doplastic && _domoney) then {
        ["OT_wood", _wood, _factoryPos]       call OT_fnc_takeFromCargoContainers;
        ["OT_steel", _steel, _factoryPos]     call OT_fnc_takeFromCargoContainers;
        ["OT_plastic", _plastic, _factoryPos] call OT_fnc_takeFromCargoContainers;
        [-_costtoproduce] call OT_fnc_resistanceFunds;
        _timespent = _timespent + OT_factoryProductionMulti;
    } else {
        private _need = "";
        if !(_dowood)    then { _need = _need + format ["%1 x wood ",    _wood] };
        if !(_dosteel)   then { _need = _need + format ["%1 x steel ",   _steel] };
        if !(_doplastic) then { _need = _need + format ["%1 x plastic ", _plastic] };
        if !(_domoney)   then { _need = _need + format ["$%1 resistance funds", _costtoproduce] };
        private _errMsg = format ["Factory has insufficient resources to produce item (need: %1)", _need];
        _errMsg remoteExec ["OT_fnc_notifyMinor", 0, false];
        _factory setVariable ["BO_produceError", _errMsg, true];
    };
} else {
    _timespent = _timespent + OT_factoryProductionMulti;
};

if (_timespent >= _timetoproduce) then {
    _timespent = 0;

    // Pop the queue: decrement tail count if > 1, else delete the entry.
    _queue = _factory getVariable ["BO_queue", []];
    if (_queue isNotEqualTo []) then {
        private _item = _queue select 0;
        if ((_item select 1) > 1) then {
            _item set [1, (_item select 1) - 1];
        } else {
            _queue deleteAt 0;
        };
        _factory setVariable ["BO_queue", _queue, true];
    };

    _factory setVariable ["BO_producing", "", true];

    private _ok = [_factory, _currentCls, _numtoproduce] call BO_fnc_factoryProduceOne;
    if (!_ok) then {
        // Spawn failed (no room). Pin timespent so we don't infinite-
        // retry; the next tick will roll over to the next queue head.
        _timespent = _timetoproduce;
    };
};

_factory setVariable ["BO_producetime", _timespent, true];
