// BO: gate on shopCategory tag so unregistered factory buildings (Altis/Malden share Land_dp_smallFactory_F class) don't false-trigger vehicle hardware menu
private _building = nearestBuilding player;
if (player distance _building > 20) exitWith { false };
if ((typeOf _building) isEqualTo OT_hardwareStore && {_building getVariable ["OT_shopCategory", ""] isEqualTo "Hardware"}) exitWith { true };
false;
