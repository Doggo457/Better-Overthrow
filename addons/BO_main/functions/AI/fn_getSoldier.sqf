#include "\overthrow_main\script_component.hpp"
// BO: callers may pass either _cls or [_cls, _recruiterUID]. The UID
// form lets us look up a per-recruiter loadout override before falling
// back to the shared OT_Recruitables / OT_Loadout_Police arrays.
private _cls = "";
private _recruiterUID = "";
if (_this isEqualType "") then {
    _cls = _this;
} else {
    _cls = _this param [0, ""];
    _recruiterUID = _this param [1, ""];
};

private _loadout = [];

if (_recruiterUID isNotEqualTo "") then {
    _loadout = [_recruiterUID, _cls] call BO_fnc_loadPlayerLoadout;
};

if (_loadout isEqualTo []) then {
    if (_cls == "Police") then {
        _loadout = OT_Loadout_Police;
    } else {
        private _data = [];
        {
            if ((_x select 0) isEqualTo _cls) exitWith { _data = _x };
        } forEach (OT_recruitables);
        if (_data isEqualTo []) then {
            // Route through BO log family so level filtering / formatting is consistent.
            private _msg = format ["getSoldier: cls '%1' not found in OT_recruitables (%2 entries)", _cls, count OT_recruitables];
            BO_LOG_ERROR("recruit", _msg);
        } else {
            _loadout = _data select 1;
        };
    };
};

if (_loadout isEqualTo []) exitWith {
    // Route through BO log family so level filtering / formatting is consistent.
    private _msg = format ["getSoldier exiting early -- empty loadout for cls='%1', recruiterUID='%2'", _cls, _recruiterUID];
    BO_LOG_ERROR("recruit", _msg);
    // Return a shape-valid soldier tuple with cost=0 and empty items.
    // createSoldier's defensive check will catch the empty _cls if
    // that's what caused this and report it clearly.
    [0, _cls, [], "", [], []]
};

//calculate cost
private _cost = floor (([OT_nation, "CIV", 0] call OT_fnc_getPrice) * 1.5);

_loadout params ["_primary", "_secondary", "_handgun", "_uniform", "_vest", "_backpack", "_helmet", "_goggles", "", "_assigned"];

private _allitems = [];
{
    if (_x isEqualType "") then { _allitems pushBack _x } else { _allitems pushBack _x # 0 };
} forEach (_primary);
{
    if (_x isEqualType "") then { _allitems pushBack _x } else { _allitems pushBack _x # 0 };
} forEach (_secondary);
{
    if (_x isEqualType "") then { _allitems pushBack _x } else { _allitems pushBack _x # 0 };
} forEach (_handgun);
private _clothes = "";
if (_uniform isNotEqualTo []) then {
    _uniform params ["_item", "_items"];
    _clothes = _item;
    {
        _x params ["_itemCls", "_num"];  // BO: renamed from _cls to avoid shadowing outer unit class
        private _t = 0;
        while { _t < _num } do {
            _allitems pushBack _itemCls;
            _t = _t + 1;
        };
    } forEach (_items);
};
if (_vest isNotEqualTo []) then {
    _vest params ["_item", "_items"];
    _allitems pushBack _item;
    {
        _x params ["_itemCls", "_num"];
        private _t = 0;
        while { _t < _num } do {
            _allitems pushBack _itemCls;
            _t = _t + 1;
        };
    } forEach (_items);
};
if (_backpack isNotEqualTo []) then {
    _backpack params ["_item", "_items"];
    _allitems pushBack _item;
    {
        _x params ["_itemCls", "_num"];
        private _t = 0;
        while { _t < _num } do {
            _allitems pushBack _itemCls;
            _t = _t + 1;
        };
    } forEach (_items);
};
_allitems pushBack _helmet;
_allitems pushBack _goggles;
_allitems append _assigned;
_allitems = _allitems - [""];

private _itemqty = _allitems call BIS_fnc_consolidateArray;
private _bought = [];
{
    _x params ["_itemCls", "_num"];
    if (_itemCls isNotEqualTo "ItemMap") then {
        // BO: nearestWarehouse returns objNull when nowhere near a warehouse
        // (Training Camp without a warehouse nearby is the common case).
        // qtyInWarehouse then exits without returning a number, leaving
        // _whqty nil. Treat that as 0 stock.
        private _whqty = _itemCls call OT_fnc_qtyInWarehouse;
        if (isNil "_whqty") then { _whqty = 0 };
        if (_whqty < _num) then { _num = _num - _whqty } else { _num = 0 };
        if (_num > 0) then {
            _cost = _cost + (([OT_nation, _itemCls, 30] call OT_fnc_getPrice) * _num);
            _bought pushBack [_itemCls, _num];
        };
    };
} forEach (_itemqty);

[_cost, _cls, _loadout, _clothes, _allitems, _bought]
