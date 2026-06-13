// BO: accept _cls or [_cls, _recruiterUID] so per-recruiter loadout
// overrides flow through to each soldier in the squad.
private _cls = "";
private _recruiterUID = "";
if (_this isEqualType "") then {
    _cls = _this;
} else {
    _cls = _this param [0, ""];
    _recruiterUID = _this param [1, ""];
};

private _d = [];
{
    _x params ["_name"];
    if (_name == _cls) exitWith {
        _d = _x;
    };
} forEach (OT_Squadables);

_d params ["", "_comp", "_shortname"];
private _soldiers = [];
private _cost = 0;
private _totalitems = [];
{
    private _soldier = [_x, _recruiterUID] call OT_fnc_getSoldier;
    _totalitems = _totalitems + _soldier # 4;
    _soldiers pushBack _soldier;
} forEach (_comp);
private _bought = [];
{
    _x params ["_cls", "_num"];
    private _whqty = _cls call OT_fnc_qtyInWarehouse;
    if (_whqty < _num) then { _num = _num - _whqty } else { _num = 0 };
    if (_num > 0) then {
        _cost = _cost + (([OT_nation, _cls, 30] call OT_fnc_getPrice) * _num);
        _bought pushBack [_cls, _num];
    };
} forEach (_totalitems call BIS_fnc_consolidateArray);

[_cost, _soldiers, _bought, _shortname];
