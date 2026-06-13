#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenHalModule
 *
 * Client-side dispatcher for the "BO: HAL ..." Zeus modules. Each
 * registration passes [moduleArgs, cmd]; this opens whatever dialog
 * the command needs and remoteExecs BO_HAL_fnc_halAdminCmd on the
 * server (which re-validates privileges).
 *
 * Module placement position doubles as the TARGET for position-aware
 * commands (spawnpkg, heat).
 *
 * Params: 0: ARRAY zen module args [position, logic], 1: STRING cmd
 */

params [["_moduleArgs", [], [[]]], ["_cmd", "", [""]]];
_moduleArgs params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

switch (toLower _cmd) do {

    case "status";
    case "tick";
    case "doctrine";
    case "clearops": {
        [_cmd, [], clientOwner] remoteExec ["BO_HAL_fnc_halAdminCmd", 2, false];
    };

    case "silent": {
        [
            "HAL: Set Silent Ticks (dwell counter -- 2+ recon, 8+ CTRG hunt)",
            [["EDIT", "Silent ticks:", str (server getVariable ["BO_HAL_silentTicks", 0])]],
            {
                params ["_result"];
                ["silent", [parseNumber (_result # 0)], clientOwner] remoteExec ["BO_HAL_fnc_halAdminCmd", 2, false];
            },
            {},
            []
        ] call zen_dialog_fnc_create;
    };

    case "heat": {
        [
            "HAL: Add Heat at this position",
            [["SLIDER", "Heat amount:", [0, 1, 0.5, 2]]],
            {
                params ["_result", "_args"];
                ["heat", [_args # 0, _result # 0], clientOwner] remoteExec ["BO_HAL_fnc_halAdminCmd", 2, false];
            },
            {},
            [_position]
        ] call zen_dialog_fnc_create;
    };

    case "maxops": {
        [
            "HAL: Set Max Concurrent Ops (1-12)",
            [["EDIT", "Max ops:", str (missionNamespace getVariable ["BO_HAL_maxConcurrentOps", 4])]],
            {
                params ["_result"];
                ["maxops", [parseNumber (_result # 0)], clientOwner] remoteExec ["BO_HAL_fnc_halAdminCmd", 2, false];
            },
            {},
            []
        ] call zen_dialog_fnc_create;
    };

    case "spawnpkg": {
        private _ids = [
            "LGT_INFANTRY", "LGT_INFANTRY_RURAL", "MED_SQUAD", "FORTIFIED_POSITION",
            "LIGHT_ARMOR", "HEAVY_ARMOR", "AIR_ASSAULT", "AIR_CAS_DRONE",
            "AIR_LIGHT", "AIR_ATTACK", "RECON_DRONE", "RECON_GROUND",
            "RECON_AIR", "CTRG_HUNTER", "INTERDICTION", "FACTORY_SABOTAGE"
        ];
        [
            "HAL: Spawn Package targeting this position",
            [["COMBO", "Package:", [_ids, _ids, 0]]],
            {
                params ["_result", "_args"];
                _args params ["_pos", "_ids"];
                private _pick = _ids param [_result # 0, ""];
                if (_pick isNotEqualTo "") then {
                    ["spawnpkg", [_pick, _pos], clientOwner] remoteExec ["BO_HAL_fnc_halAdminCmd", 2, false];
                };
            },
            {},
            [_position, _ids]
        ] call zen_dialog_fnc_create;
    };

    default {};
};
