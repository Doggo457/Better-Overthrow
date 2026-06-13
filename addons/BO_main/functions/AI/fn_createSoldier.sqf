#include "\overthrow_main\script_component.hpp"
params ["_soldier", "_pos", "_group", ["_takeFromWarehouse", true]];
_soldier params ["_cost", "_cls", "_loadout", "_clothes", "_allitems"];
if (_cls == "Police") then { _cls = OT_Unit_Police };

// BO: defensive check. createUnit with an empty/nil _cls throws
// "Bad vehicle type" with no context about the caller. Log loudly
// so we can trace where the soldier tuple is being malformed.
if (isNil "_cls" || {!(_cls isEqualType "")} || {_cls isEqualTo ""}) exitWith {
    // Route through BO log family so level filtering / formatting is consistent.
    private _msg = format ["createSoldier got bad _cls: %1 (soldier tuple: %2)", _cls, _soldier];
    BO_LOG_ERROR("recruit", _msg);
    "Recruit failed: bad unit class (check RPT)" call OT_fnc_notifyMinor;
    objNull
};

//Take from warehouse
if (_takeFromWarehouse) then {
    private _unitCls = _cls;  // preserve in case the inner forEach corrupts _cls
    {
        _x params ["_itemCls", "_num"];
        [_itemCls, _num] call OT_fnc_removeFromWarehouse;
    } forEach (_allitems call BIS_fnc_consolidateArray);
    _cls = _unitCls;
};

private _start = [[[_pos, 30]]] call BIS_fnc_randomPos;
private _civ = _group createUnit [_cls, _start, [], 0, "NONE"];

if (isNull _civ) then {
    // Route through BO log family so level filtering / formatting is consistent.
    private _msg = format ["createUnit returned objNull for cls=%1, start=%2", _cls, _start];
    BO_LOG_ERROR("recruit", _msg);
};

private _identity = call OT_fnc_randomLocalIdentity;
_identity pushBack (selectRandom OT_voices_local);
[_civ, _identity] call OT_fnc_applyIdentity;

_civ setRank "LIEUTENANT";
_civ setSkill ["courage", 1];

_civ setUnitLoadout [_loadout, false];

_civ;
