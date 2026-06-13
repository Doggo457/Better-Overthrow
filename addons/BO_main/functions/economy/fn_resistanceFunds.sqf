private _funds = server getVariable ["money", 0];
if (_this isNotEqualTo []) then {
    _funds = _funds + (_this select 0);
    server setVariable ["money", _funds, true];
};
_funds;
