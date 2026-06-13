private _warehouse = [player] call OT_fnc_nearestWarehouse;
// BO: when there's no warehouse nearby, OT's original code returned
// nil and hinted "No warehouse near by!" on EVERY call -- 30+ hints
// per recruit because getSoldier loops every item in the loadout
// against this. Worse, the nil return tripped `_whqty < _num` in
// getSoldier with "Generic error in expression". Silent 0 is the
// right behaviour: caller treats "not in stock" as "must purchase",
// which is what an empty warehouse means anyway.
if (_warehouse == objNull) exitWith { 0 };

private _ret = 0;
private _d = _warehouse getVariable [format ["item_%1", _this], [_this, 0, [0]]];
if (_d isEqualType []) then {
    _d params ["", "_in"];
    _ret = _in;
};
_ret
