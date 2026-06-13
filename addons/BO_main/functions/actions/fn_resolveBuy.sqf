#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_resolveBuy
 *
 * Server-authoritative resolver for the shared-state mutations that
 * happen during a shop purchase (fn_buy). Three distinct buy variants
 * touch SHARED server-namespace state that was previously RMW'd from
 * the client, opening exploit windows where two concurrent clients
 * could observe the same pre-state and clobber each other:
 *
 *   1. "standing"    - increment server "standing<faction>" by N
 *   2. "blueprint"   - pushBack a vehicle class into "GEURblueprints"
 *                      (idempotent: skips if already present)
 *   3. "chems"       - debit server "reschems" by N (floor at 0)
 *
 * The chems debit is the most security-critical: the prior code did
 * `_chems = server getVariable [...]` early in the buy, then later
 * wrote back `_chems - cost` after the player object was already
 * debited locally. Two concurrent explosive purchases would both see
 * the same _chems snapshot and effectively double-spend chemicals.
 * Routing through this single-RMW server-side helper closes that.
 *
 * Intended call site:
 *   ["standing", [_factionId, _delta]] remoteExec ["BO_fnc_resolveBuy", 2, false];
 *   ["blueprint", [_cls]]              remoteExec ["BO_fnc_resolveBuy", 2, false];
 *   ["chems", [_delta]]                remoteExec ["BO_fnc_resolveBuy", 2, false];
 *
 * Params:
 *   0: STRING - mutation kind ("standing" | "blueprint" | "chems")
 *   1: ARRAY  - kind-specific payload (see above)
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [
    ["_kind", "", [""]],
    ["_payload", [], [[]]]
];

if (_kind isEqualTo "") exitWith {};

switch (_kind) do {
    case "standing": {
        _payload params [
            ["_faction", "", [""]],
            ["_delta", 0, [0]]
        ];
        if (_faction isEqualTo "") exitWith {};
        if (_delta isEqualTo 0) exitWith {};
        private _key = format ["standing%1", _faction];
        private _current = server getVariable [_key, 0];
        server setVariable [_key, _current + _delta, true];
    };

    case "blueprint": {
        _payload params [["_cls", "", [""]]];
        if (_cls isEqualTo "") exitWith {};
        private _blueprints = server getVariable ["GEURblueprints", []];
        // Idempotent: two concurrent buyers shouldn't double-push.
        if (_cls in _blueprints) exitWith {
            private _msg = format ["resolveBuy blueprint: skip duplicate %1", _cls];
            BO_LOG_INFO("econ", _msg);
        };
        _blueprints pushBack _cls;
        server setVariable ["GEURblueprints", _blueprints, true];
    };

    case "chems": {
        _payload params [["_delta", 0, [0]]];
        if (_delta isEqualTo 0) exitWith {};
        private _current = server getVariable ["reschems", 0];
        // Floor at 0 so a stale snapshot can't drive the counter
        // negative if two debits race against each other.
        private _new = (_current + _delta) max 0;
        server setVariable ["reschems", _new, true];
    };

    default {
        private _msg = format ["resolveBuy: unknown kind '%1'", _kind];
        BO_LOG_WARN("econ", _msg);
    };
};
