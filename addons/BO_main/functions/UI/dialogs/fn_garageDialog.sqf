#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garageDialog
 *
 * Open BO_dialog_garage (IDD 8052). Populates a two-tab listbox
 * (Stored | Nearby) and routes button clicks to the four server-auth
 * fns via remoteExec.
 *
 * Params:
 *   0: OBJECT - the warehouse we're acting on. If objNull, derived
 *               from the player's nearestRealEstate.
 *
 * Returns: nothing.
 */

params [["_warehouse", objNull, [objNull]]];

if (isNull _warehouse) then {
    private _rb = player call OT_fnc_nearestRealEstate;
    if (_rb isEqualType []) then {
        _warehouse = _rb param [0, objNull];
    };
};

if (!(createDialog "BO_dialog_garage")) exitWith {};

disableSerialization;
private _disp = uiNamespace getVariable ["BO_dialog_garage", displayNull];
uiNamespace setVariable ["BO_dialog_garage_warehouse", _warehouse];

// Populate routine -- bound to uiNamespace so the tab buttons in the
// dialog HPP can call it via getVariable. _d is the display, _mode is
// "stored" or "nearby".
private _populate = {
    params ["_d", "_mode"];
    if (isNull _d) exitWith {};
    private _lb = _d displayCtrl 1500;
    lbClear _lb;
    private _slotsPer = ["bo_garage_slots_per_warehouse", 5] call BIS_fnc_getParamValue;
    private _wh = uiNamespace getVariable ["BO_dialog_garage_warehouse", objNull];
    private _cap = (count (warehouse getVariable ["owned", []])) * _slotsPer;
    private _summary = _d displayCtrl 1101;

    if (_mode isEqualTo "stored") then {
        private _garage = server getVariable ["BO_garage", []];
        {
            _x params [
                ["_id", ""],
                ["_cls", ""],
                ["_uid", ""],
                ["_origName", ""],
                ["_ins", false],
                ["_prem", 0],
                ["_cond", []],
                ["_disp", ""],
                ["_storedAt", 0],
                ["_captured", false]
            ];
            private _fuelV = _cond param [0, 0];
            private _hp = _cond param [1, [[],[],[]]];
            private _hpDmg = _hp param [2, []];
            private _avgDmg = if (count _hpDmg > 0) then {
                private _s = 0;
                { _s = _s + _x } forEach _hpDmg;
                _s / (count _hpDmg)
            } else { 0 };
            private _capTag = if (_captured) then { " [CAPTURED]" } else { "" };
            private _insTag = if (_ins) then { "INSURED" } else { "uninsured" };
            private _vname = _cls call OT_fnc_vehicleGetName;
            private _row = format [
                "%1%2  |  Owner: %3  |  Fuel %4%%  |  Dmg %5%%  |  %6",
                _vname,
                _capTag,
                _origName,
                round (_fuelV * 100),
                round (_avgDmg * 100),
                _insTag
            ];
            private _lbIdx = _lb lbAdd _row;
            _lb lbSetData [_lbIdx, _id];
            // (_storedAt is a raw serverTime float -- meaningless to
            // display and stale across loads; class + nickname only.)
            _lb lbSetTooltip [_lbIdx, format ["Class: %1%2", _cls, ["", format [" | '%1'", _disp]] select (_disp isNotEqualTo "")]];
        } forEach _garage;
        private _txt = format ["<t align='center'>Stored Vehicles  (%1 / %2)</t>", count _garage, _cap];
        _summary ctrlSetStructuredText parseText _txt;
    } else {
        // Nearby drivable vehicles owned by player OR unowned/captured.
        if (isNull _wh) exitWith {};
        private _nearby = (getPosATL _wh) nearObjects ["AllVehicles", 80] select {
            alive _x
                && {!(_x isKindOf "CAManBase")}
                && {!(_x getVariable ["BO_storingInProgress", false])}
        };
        {
            private _veh = _x;
            private _cls = typeOf _veh;
            private _ins = _veh getVariable ["BO_insured", false];
            private _insTag = if (_ins) then { "INSURED" } else { "uninsured" };
            private _vname = _cls call OT_fnc_vehicleGetName;
            private _row = format [
                "%1  |  Fuel %2%%  |  Dmg %3%%  |  %4",
                _vname,
                round ((fuel _veh) * 100),
                round ((damage _veh) * 100),
                _insTag
            ];
            private _lbIdx = _lb lbAdd _row;
            _lb lbSetData [_lbIdx, netId _veh];
        } forEach _nearby;
        private _txt = format ["<t align='center'>Nearby Vehicles  (%1 listed)</t>", count _nearby];
        _summary ctrlSetStructuredText parseText _txt;
    };
};

uiNamespace setVariable ["BO_garageDialog_populate", _populate];
[_disp, "nearby"] call _populate;
