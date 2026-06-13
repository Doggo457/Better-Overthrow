#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_priorityFromKit
 *
 * Priority ladder (addendum): when budget can only fund one response,
 * the heaviest observed threat wins.
 *
 *   MBT (5) = heli-attack (5) = jet (5) > IFV (4)
 *   > AT-capable (3) = AA-capable (3)
 *   > sniper (2) = transport-armed (2)
 *   > infantry (1) = transport-light (1) = heli-light (1) > medic (0)
 *
 * Params: 0: STRING role tag (from inferRole)
 * Returns: NUMBER priority
 */

params [["_role", "infantry", [""]]];

switch (_role) do {
    case "MBT";
    case "heli-attack";
    case "jet":             { 5 };
    case "IFV":             { 4 };
    case "AT-capable";
    case "AA-capable":      { 3 };
    case "sniper";
    case "transport-armed": { 2 };
    case "medic":           { 0 };
    default                 { 1 };
}
