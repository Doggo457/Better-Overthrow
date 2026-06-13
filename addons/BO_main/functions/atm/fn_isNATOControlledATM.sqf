#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_isNATOControlledATM
 *
 * Tests whether the ATM is inside a NATO-controlled town. Used to
 * apply a higher withdrawal fee. NATO-controlled simply means the
 * town is not in OT's NATOabandoned list (i.e. the resistance has
 * not yet liberated it).
 */

params [["_atm", objNull, [objNull]]];
if (isNull _atm) exitWith { false };

private _nearestTown = (getPos _atm) call OT_fnc_nearestTown;
if (_nearestTown isEqualTo "") exitWith { false };

!(_nearestTown in (server getVariable ["NATOabandoned", []]))
