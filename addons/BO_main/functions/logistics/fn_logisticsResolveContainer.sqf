#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsResolveContainer
 *
 * Look up a tagged container by its persistent BO_logisticsContainerId.
 * Queries every cargo class the ACE Logistics menu is registered on,
 * dedupes by object, and matches by stored id.
 *
 * Returns objNull if no live container has this id.
 */

params [["_id", "", [""]]];
if (_id isEqualTo "") exitWith { objNull };

private _classes = [
    "B_Slingload_01_Cargo_F", "O_Slingload_01_Cargo_F", "I_Slingload_01_Cargo_F",
    "B_CargoNet_01_ammo_F",   "O_CargoNet_01_ammo_F",   "I_CargoNet_01_ammo_F",
    "B_CargoNet_01_box_F",    "O_CargoNet_01_box_F",    "I_CargoNet_01_box_F",
    "Box_NATO_AmmoVeh_F",     "Box_East_AmmoVeh_F",     "Box_IND_AmmoVeh_F",
    "Box_NATO_Ammo_F",        "Box_East_Ammo_F",        "Box_IND_Ammo_F",
    "B_supplyCrate_F",        "ReammoBox_F"
];

private _candidates = [];
{ _candidates append (allMissionObjects _x) } forEach _classes;

private _seen = [];
private _hit = objNull;
{
    if (_x in _seen) then { continue };
    _seen pushBack _x;
    if ((_x getVariable ["BO_logisticsContainerId", ""]) isEqualTo _id) exitWith {
        _hit = _x;
    };
} forEach _candidates;

_hit
