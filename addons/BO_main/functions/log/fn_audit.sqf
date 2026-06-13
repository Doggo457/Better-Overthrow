#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_audit
 *
 * Record a player-initiated state change to the audit log. The audit
 * log is a server-namespace hashmap of FIFO-rotated event arrays
 * keyed by category. Audit entries also mirror to the RPT via
 * BO_fnc_log so external tooling can grep them.
 *
 * Use this when the action has a known player actor (current
 * `player`). For server-initiated events use BO_fnc_auditServer.
 * For grouped batch operations use BO_fnc_auditGroup.
 *
 * Params:
 *   0: STRING - category (use AUDIT_* macros from script_macros.hpp)
 *   1: STRING - description (human-readable, shown in viewer)
 *   2: ANY    - details (optional payload, stored opaquely)
 *
 * Returns: nothing.
 *
 * Side effects:
 *   - server-side: appends to BO_auditLog hashmap (capped per category)
 *   - client-side: forwards to server via remoteExec
 *   - all sides: also fires BO_fnc_log at INFO level
 */

// `_details` is genuinely optional; bind it as a free variable and
// substitute an empty array if not provided. A nil entry in an SQF
// array literal causes truncation at that slot, so passing raw
// `_details` to the arrays below would silently lose downstream args.
params [
    ["_category", "general", [""]],
    ["_description", "", [""]],
    "_details"
];

private _detailsVal = if (isNil "_details") then { [] } else { _details };

// If we're on a client, route to server.
if (!isServer) exitWith {
    [_category, _description, _detailsVal, getPlayerUID player, name player] remoteExec ["BO_fnc_auditServer", 2, false];
};

// Server-side path.
private _actorUID = if (hasInterface) then { getPlayerUID player } else { "" };
private _actorName = if (hasInterface) then { name player } else { "" };

[_category, _description, _detailsVal, _actorUID, _actorName] call BO_fnc_auditServer;
