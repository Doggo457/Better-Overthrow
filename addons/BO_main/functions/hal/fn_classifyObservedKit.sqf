#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_classifyObservedKit
 *
 * Build the observedKit tuple stored in NATOknownTargets slot 6:
 *   ["primaryWeapon", "backpack", "vehicleClass", roleTag]
 *
 * Params: 0: OBJECT unit
 * Returns: ARRAY observedKit
 */

params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith { ["", "", "", "infantry"] };

private _vehCls = "";
if (vehicle _unit isNotEqualTo _unit) then { _vehCls = typeOf (vehicle _unit) };
if (!(_unit isKindOf "Man")) then { _vehCls = typeOf _unit };

[
    if (_unit isKindOf "Man") then { primaryWeapon _unit } else { "" },
    if (_unit isKindOf "Man") then { backpack _unit } else { "" },
    _vehCls,
    [_unit] call BO_HAL_fnc_inferRole
]
