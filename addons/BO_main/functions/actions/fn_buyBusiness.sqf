// MP race + missing broadcast: gather context client-side, then route
// the atomic check-debit-write through BO_fnc_buyBusinessServer.
// Original OT version did the RMW on the client and forgot the third
// `true` on the employ setVariable, breaking dedicated-MP worker spawn.
private _b = player call OT_fnc_nearestLocation;
if ((_b select 1) isEqualTo "Business") then {
    if (call OT_fnc_playerIsGeneral) then {
        private _name = (_b select 0);
        private _pos = (_b select 2) select 0;
        private _price = _name call OT_fnc_getBusinessPrice;
        private _money = [] call OT_fnc_resistanceFunds;
        if (_money >= _price) then {
            // Server validates UID, re-checks funds, performs atomic
            // GEURowned/employ writes with broadcast=true.
            [_name, _pos, getPlayerUID player, false] remoteExec ["BO_fnc_buyBusinessServer", 2, false];
        } else {
            "The resistance cannot afford this" call OT_fnc_notifyMinor;
        };
    };
} else {
    if (player distance OT_factoryPos < 150) then {
        if (call OT_fnc_playerIsGeneral) then {
            private _name = "Factory";

            private _owned = server getVariable ["GEURowned", []];
            if (!(_name in _owned)) then {
                private _pos = OT_factoryPos;
                private _price = _name call OT_fnc_getBusinessPrice;
                private _money = [] call OT_fnc_resistanceFunds;
                if (_money >= _price) then {
                    // Server-side path also handles the factory cargo
                    // container spawn so it stays inside the same
                    // atomic transaction.
                    [_name, _pos, getPlayerUID player, true] remoteExec ["BO_fnc_buyBusinessServer", 2, false];
                } else {
                    "The resistance cannot afford this" call OT_fnc_notifyMinor;
                };
            } else {
                //Manage
                [] call OT_fnc_factoryDialog;
            };
        };
    };
};
