closeDialog 0;
OT_inputHandler = {
    private _input = ctrlText 1400;
    if (_input isEqualType "" && count _input > 64) exitWith { hint "You can't donate that much!" };
    private _val = parseNumber _input;
    private _cash = player getVariable ["money", 0];
    if (_val > _cash) then { _val = _cash };
    if (_val > 0) then {
        // MP race: resistance funds ("money" on server NS) is shared state. Route delta through server-only adjuster.
        [_val, format ["Donation by %1", name player]] remoteExec ["BO_fnc_adjustResistanceFunds", 2, false];
        [-_val] call OT_fnc_money;
        format ["%1 donated $%2 to the resistance", name player, [_val, 1, 0, true] call CBA_fnc_formatNumber] remoteExec ["OT_fnc_notifyMinor", 0, false];
    };
};

["How much to donate to resistance?", player getVariable ["money", 100]] spawn OT_fnc_inputDialog;
