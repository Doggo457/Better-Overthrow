#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryLoop
 *
 * Server-only. Installs the per-frame handler that drives all
 * placed factories. Replaces the GUERLoop:255-427 single-factory
 * tick block. Round-robin processing with a per-call budget so
 * a player with 50+ factories doesn't tank server FPS.
 *
 * Tick semantics:
 *   - The PFH fires every BO_factoryLoopInterval seconds (default 1s).
 *   - Production rate is measured in *game minutes*; a factory ticks
 *     when the current game-minute differs from its BO_lastTickMin.
 *     This preserves the exact production rate of the legacy single-
 *     factory model (which ticked once per game minute).
 *   - Each PFH iteration processes UP TO BO_factoryTickBudget
 *     factories that haven't yet ticked this minute, starting from
 *     a round-robin cursor. Excess factories defer to the next PFH
 *     iteration. At 1Hz with 60s game minutes, 50 factories ticked
 *     8-at-a-time complete in ~7 seconds per game-minute -- well
 *     inside the production granularity.
 *
 * Null/dead pruning: any registry entry that fails alive-check is
 * removed via BO_fnc_unregisterFactory before the tick budget is
 * applied to the remaining entries.
 *
 * Idempotent: re-calling installs once; subsequent calls no-op.
 */

SERVER_ONLY;

if (!isNil "BO_factoryLoopHandle") exitWith {
    BO_LOG_DEBUG("factory","factoryLoop already installed");
};

private _interval = missionNamespace getVariable ["BO_factoryLoopInterval", 1.0];
if (_interval <= 0) then { _interval = 1.0 };

// Round-robin cursor stored at module scope so it persists between
// PFH calls. Re-init even on re-install so an old cursor doesn't
// indexerror after the registry shrank.
BO_factoryRRCursor = 0;
BO_factoryLastMinSeen = -1;

BO_factoryLoopHandle = [{
    private _registry = server getVariable ["BO_buildFactories", []];
    if (_registry isEqualTo []) exitWith {};

    // Drop null/dead factories before tick allocation. This keeps
    // the budget pointed at real work; iterating dead entries
    // would waste tick slots and risk net-id stale lookups.
    private _alive = _registry select { !isNull _x && alive _x };
    if (count _alive != count _registry) then {
        server setVariable ["BO_buildFactories", _alive, true];
        _registry = _alive;
        private _msg = format ["factoryLoop pruned to %1 alive factories", count _registry];
        BO_LOG_DEBUG("factory", _msg);
    };
    if (_registry isEqualTo []) exitWith {};

    private _n = count _registry;
    private _budget = missionNamespace getVariable ["BO_factoryTickBudget", 8];
    if (_budget < 1) then { _budget = 1 };

    private _currentMin = date select 4;
    private _processed = 0;
    private _scanned = 0;

    // Round-robin: start at cursor, wrap once. Stop when we've
    // either processed _budget factories or scanned the entire
    // registry without finding more pending work.
    while { _processed < _budget && _scanned < _n } do {
        private _i = BO_factoryRRCursor mod _n;
        private _factory = _registry select _i;

        BO_factoryRRCursor = BO_factoryRRCursor + 1;
        _scanned = _scanned + 1;

        if (!isNull _factory && {alive _factory}) then {
            private _lastMin = _factory getVariable ["BO_lastTickMin", -1];
            if (_lastMin != _currentMin) then {
                [_factory] call BO_fnc_factoryTick;
                _factory setVariable ["BO_lastTickMin", _currentMin, true];
                _processed = _processed + 1;
            };
        };
    };

    if (_processed > 0) then {
        private _msg = format ["factoryLoop tick: processed %1/%2 factories (cursor=%3)", _processed, _n, BO_factoryRRCursor];
        BO_LOG_DEBUG("factory", _msg);
    };
}, _interval, []] call CBA_fnc_addPerFrameHandler;

private _msg = format ["factoryLoop installed (interval=%1s, budget=%2)", _interval, missionNamespace getVariable ["BO_factoryTickBudget", 8]];
BO_LOG_INFO("factory", _msg);
