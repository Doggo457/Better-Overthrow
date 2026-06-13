params ["_veh", "_pos", "_fnc"];

// BO: accept OT_fnc_* and BO_fnc_* by resolving through missionNamespace
// first. Legacy substring-match path is kept only as a fallback for
// pre-CfgFunctions OT init functions referenced by short name.
private _code = missionNamespace getVariable _fnc;
if (!isNil "_code" && {_code isEqualType {}}) exitWith {
    [_pos, _veh] spawn _code;
};

// Legacy resolver (handles short-name strings like "policeStation"
// in old buildable entries).
_code = {};
if ("policeStation" in _fnc) then { _code = OT_fnc_initPoliceStation };
if ("trainingCamp"  in _fnc) then { _code = OT_fnc_initTrainingCamp };
if ("warehouse"     in _fnc) then { _code = OT_fnc_initWarehouse };
if ("workshop"      in _fnc) then { _code = OT_fnc_initWorkshop };

[_pos, _veh] spawn _code;
