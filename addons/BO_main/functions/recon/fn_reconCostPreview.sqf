#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconCostPreview
 *
 * Pure(-ish) read function. Given scope + key returns
 *   [cost, estUnitCount, standing]
 * so the dialog can render the confirm row before payment. Cheap unit
 * count is a heuristic scaled by NATOresources; the real scan happens
 * server-side at arm time.
 *
 * Params:
 *   0: STRING - scope    ("TOWN" | "REGION" | "MAP")
 *   1: STRING - scopeKey (town/objective name; "" for MAP)
 *
 * Returns: [cost, est, standing]
 */

params [
    ["_scope", "TOWN", [""]],
    ["_scopeKey", "", [""]]
];

private _costTown   = missionNamespace getVariable ["BO_reconCostTown", 500];
private _costRegion = missionNamespace getVariable ["BO_reconCostRegion", 2000];
private _costMap    = missionNamespace getVariable ["BO_reconCostMap", 8000];

private _cost = 0;
private _standing = 0;
call {
    if (_scope isEqualTo "TOWN") exitWith {
        _cost = _costTown;
        _standing = server getVariable [format ["rep%1", _scopeKey], 0];
    };
    if (_scope isEqualTo "REGION") exitWith {
        _cost = _costRegion;
        private _objPos = [];
        {
            _x params ["_p", "_n"];
            if (_n isEqualTo _scopeKey) exitWith { _objPos = _p };
        } forEach (OT_objectiveData + OT_airportData);
        private _town = if (_objPos isEqualTo []) then { "" } else { _objPos call OT_fnc_nearestTown };
        _standing = server getVariable [format ["rep%1", _town], 0];
    };
    _cost = _costMap;
    _standing = server getVariable ["rep", 0];
};

private _natoRes = server getVariable ["NATOresources", 0];
private _est = call {
    if (_scope isEqualTo "TOWN")   exitWith { 5 + floor (_natoRes / 400) };
    if (_scope isEqualTo "REGION") exitWith { 15 + floor (_natoRes / 150) };
    50 + floor (_natoRes / 50)
};

[_cost, _est, _standing]
