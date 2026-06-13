#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_loadPricePack
 *
 * Load a curated mod-pack price file and apply each entry to the
 * cost namespace. Entries override any prior price (so packs take
 * precedence over OT's auto-heuristic but get overridden by
 * BO_basePrice config attributes and admin runtime overrides).
 *
 * Pack file format (plain SQF returning an array):
 *
 *   [
 *     ["rhs_weap_m4a1_grip", [1400, 0, 2, 0]],   // [base, wood, steel, plastic]
 *     ["rhs_30Rnd_556x45_M855A1_Stanag", [25, 0, 0.1, 0]],
 *     ...
 *   ]
 *
 * Params:
 *   0: STRING - pack name (for logging/audit)
 *   1: STRING - file path
 *
 * Returns: SCALAR — entries applied.
 */

SERVER_ONLY_RET(0);

params [
    ["_packName", "", [""]],
    ["_path", "", [""]]
];

if (!fileExists _path) exitWith { 0 };

private _entries = call compile preprocessFileLineNumbers _path;
if (!(_entries isEqualType [])) exitWith {
    private _logMsg = format ["Pack %1 did not return an array", _packName];
    BO_LOG_WARN("pricing", _logMsg);
    0
};

private _applied = 0;
{
    _x params [
        ["_cls", "", [""]],
        ["_costArr", [10, 0, 0, 0], [[]]]
    ];
    if (_cls isNotEqualTo "" && isClass (configFile >> "CfgWeapons" >> _cls) || isClass (configFile >> "CfgVehicles" >> _cls) || isClass (configFile >> "CfgMagazines" >> _cls)) then {
        cost setVariable [_cls, _costArr, true];
        _applied = _applied + 1;
    };
} forEach _entries;

private _doneMsg = format ["Pack '%1' applied %2 entries", _packName, _applied];
BO_LOG_INFO("pricing", _doneMsg);
_applied
