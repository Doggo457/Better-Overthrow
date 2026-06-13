params ["_unit", "_town"];

_unit setVariable ["polgarrison", _town, true];

_unit addEventHandler [
    "HandleDamage",
    {
        private _src = _this select 3;
        if (captive _src) then {
            if (!isNull objectParent _src || (_src call OT_fnc_unitSeenNATO)) then {
                _src setCaptive false;
            };
        };
    }
];
