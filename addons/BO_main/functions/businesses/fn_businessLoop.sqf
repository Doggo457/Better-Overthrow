#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_businessLoop
 *
 * Server-only. Installs the per-frame handler that drives all
 * BO production businesses (Lumberyard, Mine, Vineyard, Winery,
 * Olive Plantation, Chemical Plant). Same shape as
 * BO_fnc_factoryLoop: chunked round-robin with a per-call budget
 * so a player with N businesses doesn't tank server FPS.
 *
 * Tick semantics:
 *   - The PFH fires every BO_businessLoopInterval seconds.
 *   - Production rate is measured in *game hours*; a business ticks
 *     when the current game-hour differs from its BO_businessLastHour.
 *     One tick produces _outputPerHr items and pays one hour of wages.
 *   - Each PFH iteration processes UP TO BO_businessTickBudget
 *     pending businesses, starting from a round-robin cursor.
 *
 * Null/dead pruning: any registry entry that fails alive-check is
 * removed via BO_fnc_unregisterBusiness before tick budget is applied.
 *
 * Idempotent: re-calling installs once; subsequent calls no-op.
 */

if (!isServer) exitWith {};

if (!isNil "BO_businessLoopHandle") exitWith {
    BO_LOG_DEBUG("business","businessLoop already installed");
};

private _interval = missionNamespace getVariable ["BO_businessLoopInterval", 10.0];
if (_interval <= 0) then { _interval = 10.0 };

BO_businessRRCursor = 0;

BO_businessLoopHandle = [{
    private _registry = server getVariable ["BO_buildBusinesses", []];
    if (_registry isEqualTo []) exitWith {};

    // Drop null/dead businesses before tick allocation.
    private _alive = _registry select { !isNull _x && alive _x };
    if (count _alive != count _registry) then {
        server setVariable ["BO_buildBusinesses", _alive, true];
        _registry = _alive;
        private _msg = format ["businessLoop pruned to %1 alive businesses", count _registry];
        BO_LOG_DEBUG("business", _msg);
    };
    if (_registry isEqualTo []) exitWith {};

    private _n = count _registry;
    private _budget = missionNamespace getVariable ["BO_businessTickBudget", 8];
    if (_budget < 1) then { _budget = 1 };

    private _currentHour = date select 3;
    private _processed = 0;
    private _scanned = 0;

    while { _processed < _budget && _scanned < _n } do {
        private _i = BO_businessRRCursor mod _n;
        private _business = _registry select _i;

        BO_businessRRCursor = BO_businessRRCursor + 1;
        _scanned = _scanned + 1;

        if (!isNull _business && {alive _business}) then {
            private _lastHour = _business getVariable ["BO_businessLastHour", -1];
            if (_lastHour != _currentHour) then {
                [_business] call BO_fnc_businessTick;
                _business setVariable ["BO_businessLastHour", _currentHour, true];
                _processed = _processed + 1;
            };
        };
    };

    if (_processed > 0) then {
        private _msg = format ["businessLoop tick: processed %1/%2 businesses (cursor=%3)", _processed, _n, BO_businessRRCursor];
        BO_LOG_DEBUG("business", _msg);
    };
}, _interval, []] call CBA_fnc_addPerFrameHandler;

private _msg = format ["businessLoop installed (interval=%1s, budget=%2)", _interval, missionNamespace getVariable ["BO_businessTickBudget", 8]];
BO_LOG_INFO("business", _msg);
