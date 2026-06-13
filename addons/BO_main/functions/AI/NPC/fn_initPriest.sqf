params ["_unit"];

_unit setSkill ["courage", 1];

private _identity = call OT_fnc_randomLocalIdentity;
_identity set [1, selectRandom OT_clothes_priest];
[_unit, _identity] call OT_fnc_applyIdentity;

removeAllWeapons _unit;
removeAllAssignedItems _unit;
removeGoggles _unit;
removeBackpack _unit;
removeHeadgear _unit;
removeVest _unit;

[_unit, "self"] call OT_fnc_setOwner;

_unit addEventHandler [
    "FiredNear",
    {
        params ["_u"];
        if !(_u getVariable ["fleeing", false]) then {
            _u setVariable ["fleeing", true, false];
            _u setBehaviour "COMBAT";
            _u allowFleeing 1;
            _u setSkill ["courage", 0];
        };
    }
];
