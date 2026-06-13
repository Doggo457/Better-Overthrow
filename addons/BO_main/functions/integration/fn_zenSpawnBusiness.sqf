#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenSpawnBusiness
 *
 * Zen module: place a BO production business at the module position.
 * Combo picks the type. Wires the building into BO_buildBusinesses
 * via BO_fnc_initBusiness so the regular tick loop produces from it
 * just like a player-placed one.
 *
 * Params (Zen module signature):
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic (to be deleted)
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

[
    "Spawn Production Business",
    [
        ["COMBO", "Business type:",
            [
                ["Lumberyard", "Mine", "Vineyard", "Winery", "Olive Plantation", "Chemical Plant"],
                ["Lumberyard", "Mine", "Vineyard", "Winery", "Olive Plantation", "Chemical Plant"],
                0
            ]
        ]
    ],
    {
        params ["_result", "_args"];
        _args params ["_position"];
        private _type = _result # 0;

        private _model = if (!isNil "OT_workshopBuilding") then { OT_workshopBuilding } else { "Land_Cargo_House_V4_F" };
        private _building = createVehicle [_model, _position, [], 0, "NONE"];
        _building setPosATL _position;

        // Set OT_init so a save/load replays the right wrapper.
        private _initFn = call {
            if (_type isEqualTo "Lumberyard")       exitWith { "BO_fnc_initLumberyard" };
            if (_type isEqualTo "Mine")             exitWith { "BO_fnc_initMine" };
            if (_type isEqualTo "Vineyard")         exitWith { "BO_fnc_initVineyard" };
            if (_type isEqualTo "Winery")           exitWith { "BO_fnc_initWinery" };
            if (_type isEqualTo "Olive Plantation") exitWith { "BO_fnc_initOlivePlantation" };
            if (_type isEqualTo "Chemical Plant")   exitWith { "BO_fnc_initChemicalPlant" };
            ""
        };
        if (_initFn isNotEqualTo "") then {
            _building setVariable ["OT_init", _initFn, true];
            [_building, getPos _building, _initFn] call OT_fnc_initBuilding;
        };

        private _msg = format ["Zeus spawned %1 at %2", _type, mapGridPosition _building];
        _msg call OT_fnc_notifyGood;
        [AUDIT_ADMIN, _msg, [_type, _position], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_position]
] call zen_dialog_fnc_create;
