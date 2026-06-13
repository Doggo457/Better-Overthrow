#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_auditGroup
 *
 * Record a single audit entry that represents a batch of related
 * operations (mass tax disbursement, bulk shop sale, bulk convoy
 * dispatch). Prevents log spam when one logical action causes many
 * individual writes.
 *
 * The grouped entry stores a count alongside the description so the
 * viewer can show "tax income disbursed to 4 players: $1,200 each".
 *
 * Params:
 *   0: STRING - category
 *   1: STRING - description (should reference the count, e.g.
 *               "Disbursed tax to %1 players")
 *   2: SCALAR - sub-event count
 *   3: ANY    - details (optional payload)
 *
 * Returns: nothing.
 */

if (!isServer) exitWith {};

params [
    ["_category", "general", [""]],
    ["_description", "", [""]],
    ["_count", 1, [0]],
    "_details"
];

private _detailsVal = if (isNil "_details") then { [] } else { _details };
private _wrappedDetails = [_count, _detailsVal];
[_category, _description, _wrappedDetails, "", ""] call BO_fnc_auditServer;
