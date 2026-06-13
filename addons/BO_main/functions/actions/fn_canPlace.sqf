params ["_pos", "_typecls"];

private _isbase = false;
private _canplace = true;

if (_typecls != "Base") then {
    private _ob = player call OT_fnc_nearestLocation;
    if ((_ob select 1) isEqualTo "Business") then {
        private _obpos = (_ob select 2) select 0;
        private _obname = (_ob select 0);

        if (_obpos distance _pos < 250) then {
            if (_obname in (server getVariable ["GEURowned", []])) then {
                _isbase = true;
                _canplace = true;
            };
        };
    };
    // Multi-factory: any placed factory grants a 250m build zone, not
    // just the starter at OT_factoryPos. Scan the registry for the
    // nearest live factory; if it's in-range and the player owns
    // factories, this counts as a base.
    if ("Factory" in (server getVariable ["GEURowned", []])) then {
        private _registry = server getVariable ["BO_buildFactories", []];
        private _nearestRegistered = objNull;
        private _bestDist = 1e6;
        {
            if (!isNull _x && {alive _x}) then {
                private _d = _pos distance _x;
                if (_d < _bestDist) then {
                    _bestDist = _d;
                    _nearestRegistered = _x;
                };
            };
        } forEach _registry;
        if (_bestDist < 250) then {
            _isbase = true;
            _canplace = true;
        } else {
            // Legacy fallback: pre-registry callers / map-baked
            // starter that hasn't been registered yet.
            if (_pos distance OT_factoryPos < 250) then {
                _isbase = true;
                _canplace = true;
            };
        };
    };
    private _base = _pos call OT_fnc_nearestBase;
    if !(isNil "_base") then {
        if ((_base select 0) distance _pos < 100) then {
            _isbase = true;
        };
    };
    if (!_isbase) then {
        _base = _pos call OT_fnc_nearestObjective;
        if !(isNil "_base") then {
            if (((_base select 1) in (server getVariable "NATOabandoned")) && ((_base select 0) distance _pos) < 100) then {
                _isbase = true;
            };
        };
    };
} else {
    _isbase = true;
    private _base = _pos call OT_fnc_nearestBase;
    if !(isNil "_base") then {
        if ((_base select 0) distance _pos < 300) then {
            _canplace = false;
        };
    };
    if (_canplace) then {
        _base = _pos call OT_fnc_nearestObjective;
        if ((_base select 0) distance _pos < 300) then {
            _canplace = false;
        };
    };
};

if (!_canplace) exitWith { false };

if !(_isbase) then {
    //Building proximity check
    private _estate = _pos call OT_fnc_nearestRealEstate;
    if (_estate isEqualType []) then {
        private _b = _estate select 0;
        if (typeOf _b isEqualTo OT_item_Tent) exitWith { _canplace = false };
        if (_b call OT_fnc_hasOwner) then {
            private _owner = _b call OT_fnc_getOwner;
            if (_owner != getPlayerUID player) then {
                if (_typecls != "Camp" && _typecls != "Base") then {
                    _canplace = false;
                };
            } else {
                if (_typecls == "Camp" || _typecls == "Base") then {
                    _canplace = false;
                };
            };
        } else {
            _canplace = false;
        };
    } else {
        if (_typecls != "Camp" && _typecls != "Base") then {
            _canplace = false;
        };
    };
};

if (_typecls isEqualTo "Base") then {
    private _town = _pos call OT_fnc_nearestTown;
    private _postown = server getVariable _town;
    private _dist = 200;
    if ((_postown distance _pos) < _dist) then { _canplace = false };
};

_canplace;
