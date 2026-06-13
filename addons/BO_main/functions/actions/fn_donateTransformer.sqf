/*
Donate money for the transformer mission
*/

private _money = player getVariable ["money", 0];
private _town = player call OT_fnc_nearestTown;

if (_money < 4000) exitWith { hint "You don't have enough money" };

// Route the $4000 debit through OT_fnc_money so the player gets the
// standard "-$4000: Transformer donation" notify + sound and the audit
// trail stays consistent with every other money mutation. The raw
// setVariable left no on-screen confirmation at all -- a player who
// missed the dialog click had no way to know the debit happened.
[-4000, "Transformer donation"] call OT_fnc_money;
server_nosave setVariable [(_town + "transformerpaid"), true, true];
