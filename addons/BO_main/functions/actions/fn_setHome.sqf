private _b = player call OT_fnc_nearestRealEstate;
private _building = objNull;
if (_b isEqualType []) then {
    _building = (_b select 0);
};
if ((typeOf _building) in OT_allRepairableRuins) exitWith {
    private _ruins = [];
    private _type = (typeOf _building);
    {
        _x params ["_ruinClass"];
        if (_type isEqualTo _ruinClass) exitWith { _ruins = _x };
    } forEach (OT_repairableRuins);

    if (_ruins isNotEqualTo []) then {
        _ruins params ["", "_buildClass", "_price"];
        private _money = player getVariable ["money", 0];
        if (_money >= _price) then {
            [-_price] call OT_fnc_money;
            private _id = [_building] call OT_fnc_getBuildID;
            private _damaged = owners getVariable ["damagedBuildings", []];
            if (_id in _damaged) then {
                _damaged deleteAt (_damaged find _id);
                owners setVariable ["damagedBuildings", _damaged, true];
            };
            private _pos = getPosATL _building;
            private _dir = [vectorDir _building, vectorUp _building];
            deleteVehicle _building;
            private _veh = createVehicle [_buildClass, _pos, [], 0, "CAN_COLLIDE"];
            _veh enableDynamicSimulation true;
            _veh setVectorDirAndUp _dir;
            _veh setPosATL _pos;
            [_veh, getPlayerUID player] call OT_fnc_setOwner;
        } else {
            // Bare format string is a no-op; pipe through the notifier
            // so the player actually sees the price feedback.
            format ["You need $%1 to repair this building", [_price, 1, 0, true] call CBA_fnc_formatNumber] call OT_fnc_notifyMinor;
        };
    };
};
if (typeOf _building isEqualTo OT_warehouse) exitWith {
    private _price = round ((_b select 1) * 0.25);
    private _money = player getVariable ["money", 0];
    if (_money >= _price) then {
        [-_price] call OT_fnc_money;
        _building setDamage 0;
        private _id = [_building] call OT_fnc_getBuildID;
        private _damaged = owners getVariable ["damagedBuildings", []];
        if (_id in _damaged) then {
            _damaged deleteAt (_damaged find _id);
            owners setVariable ["damagedBuildings", _damaged, true];
        };
    } else {
        // Bare format string is a no-op; pipe through the notifier.
        format ["You need $%1 to repair this warehouse", [_price, 1, 0, true] call CBA_fnc_formatNumber] call OT_fnc_notifyMinor;
    };
};

if !(captive player) exitWith { "You cannot set home while wanted" call OT_fnc_notifyMinor };
private _handled = false;
private _owner = _building call OT_fnc_getOwner;
if (!isNil "_owner") then {
    if ((typeOf _building) in OT_allBuyableBuildings && _owner isEqualTo getPlayerUID player) exitWith {
        _handled = true;
        player setVariable ["home", getPos _building, true];
        "This is now your home" call OT_fnc_notifyMinor;
    };
};

if !(_handled) then {
    "You don't own any buildings nearby" call OT_fnc_notifyMinor;
};
