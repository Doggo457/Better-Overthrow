params ["_town", "_cls", ["_standing", 0]];
private _price = 0;

private _trade = player getVariable ["OT_trade", 1];
private _discount = 0;
if (_trade > 1) then {
    _discount = 0.02 * (_trade - 1);
};

private _cost = cost getVariable [_cls, [10, 0, 0, 0]];
private _baseprice = _cost select 0;

private _stability = 1.0 - ((server getVariable [format ["stability%1", _town], 100]) / 100);

if (_cls isEqualTo "WAGE") then {
    _stability = ((server getVariable [format ["stability%1", _town], 100]) / 100);
};

private _population = server getVariable [format ["population%1", _town], 1000];
if (_town isEqualTo OT_nation) then { _population = 100 };
if (_population > 2000) then { _population = 2000 };
_population = 1 - (_population / 2000);
if (_cls == "WAGE" && _town != OT_nation) then {
    _population = (_population / 2000);
};

if (_standing < -100) then { _standing = -100 };
if (_standing > 100) then { _standing = 100 };
if (_standing isEqualTo 0) then { _standing = 1 };
_standing = (_standing / 100);
_discount = _discount + (_standing * 0.2);

_price = _baseprice + (_baseprice + (_baseprice * _stability * _population) * (1 + OT_standardMarkup));
if (_cls isEqualTo "FUEL") then {
    _price = _price - 9;
};

private _final = _price - (_price * _discount);

// BO world demand events: spike buy prices at towns with an active
// event whose boosted-items list includes _cls. Skip WAGE / FUEL --
// those are scale-tied lookups, not consumer goods, and a multiplier
// there would feed back into recruit / fuel-station pricing in ways
// the player can't avoid.
if (_cls != "WAGE" && {_cls != "FUEL"}) then {
    private _evtMul = [_town, _cls] call BO_fnc_worldEventMultiplier;
    if (_evtMul > 1) then { _final = _final * _evtMul };
};

round _final;
