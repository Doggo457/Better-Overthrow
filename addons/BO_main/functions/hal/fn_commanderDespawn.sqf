#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_commanderDespawn
 *
 * Tear down the live entourage (players left the bubble, or the seat
 * moved). The commander's EXISTENCE persists as server state; only the
 * physical detail despawns. Never called with players watching (the
 * presence PFH enforces the distance + grace window).
 */

SERVER_ONLY;

if (!BO_HAL_cmdSpawned) exitWith {};
BO_HAL_cmdSpawned = false;
missionNamespace setVariable ["BO_HAL_cmdNoPlayerSince", -1];

private _grps = [];
{
    if (!isNull _x) then {
        if (_x isKindOf "Man" && {alive _x}) then { _grps pushBackUnique (group _x) };
        deleteVehicle _x;
    };
} forEach BO_HAL_cmdObjects;
{ if (!isNull _x) then { deleteGroup _x } } forEach _grps;
BO_HAL_cmdObjects = [];

["commander_despawned", []] call BO_HAL_fnc_aar;
