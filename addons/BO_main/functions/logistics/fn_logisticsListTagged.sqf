#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsListTagged
 *
 * Enumerate every tagged cargo container. Queries the same class
 * list the ACE menu registers on, dedupes by both object reference
 * and containerId so the combo never shows the same physical
 * container twice.
 *
 * Returns:
 *   [[_id, _label, _role, _ownerUID, _obj], ...]
 */

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

private _result = [];
private _seenObjs = [];
private _seenIds  = [];

{
    if (_x in _seenObjs) then { continue };
    _seenObjs pushBack _x;

    private _id = _x getVariable ["BO_logisticsContainerId", ""];
    if (_id isEqualTo "") then { continue };
    if (_id in _seenIds) then { continue };
    _seenIds pushBack _id;

    _result pushBack [
        _id,
        _x getVariable ["BO_logisticsLabel", "(unnamed)"],
        _x getVariable ["BO_logisticsRole", ""],
        _x getVariable ["BO_logisticsOwner", ""],
        _x
    ];
} forEach _candidates;

_result
