params ["_player"];
if !(alive _player) exitWith {};

private _wanted = "<br/>";
if !(captive _player) then {
    private _hiding = _player getVariable ["OT_hiding", 0];
    if ((_hiding > 0) && (_hiding < 30)) then {
        _wanted = format ["(%1) WANTED", _hiding];
    } else {
        _wanted = "WANTED";
    };
};

private _seen = "";
if (_player call OT_fnc_unitSeenNATO) then {
    _seen = "<t color='#5D8AA8'>o_o</t>";
} else {
    if (_player call OT_fnc_unitSeenCRIM) then {
        _seen = "<t color='#B2282f'>o_o</t>";
    };
};
private _qrf = "";
private _attacking = server getVariable ["NATOattacking", OT_nation];

if !(isNil "OT_QRFstart") then {
    if ((time - OT_QRFstart) < 600) exitWith {
        private _secs = 600 - round (time - OT_QRFstart);
        private _mins = 0;
        if (_secs > 59) then {
            _mins = floor (_secs / 60);
            _secs = round (_secs % 60);
        };
        if (_mins < 10) then { _mins = format ["0%1", _mins] };
        if (_secs < 10) then { _secs = format ["0%1", _secs] };
        _qrf = format ["<t size='0.7'>Battle of %1</t><br/>Starting (%2:%3)", _attacking, _mins, _secs];
    };

    if ((time - OT_QRFstart) > 600) then {
        private _progress = server getVariable ["QRFprogress", 0];
        if (_progress > 0) then {
            _qrf = format ["<t size='0.7'>Battle of %1</t><br/><t color='#5D8AA8'>(%2%3)</t>", _attacking, round (_progress * 100), '%'];
        } else {
            _qrf = format ["<t size='0.7'>Battle of %1</t><br/><t color='#008000'>(%2%3)</t>", _attacking, round abs (_progress * 100), '%'];
        };
    };
};

// War Level is the independent aggression dial (BO_warLevel, broadcast
// by the server), no longer derived from the NATOresources budget.
private _warLevel = round ((server getVariable ["BO_warLevel", 1]) min 10 max 0);
private _warColor = switch (true) do {
    case (_warLevel >= 9): { "#dd4444" };
    case (_warLevel >= 7): { "#dd8855" };
    case (_warLevel >= 4): { "#dddd66" };
    default              { "#88dd88" };
};

private _txt = format [
    "<t size='0.7' align='right' color='%1'>War Level %2/10</t><br/><t size='0.9' align='right'>$%3<br/>%4<br/>%5<br/>%6</t>",
    _warColor,
    _warLevel,
    [_player getVariable ["money", 0], 1, 0, true] call CBA_fnc_formatNumber,
    _seen,
    _wanted,
    _qrf
];

private _setText = (uiNamespace getVariable "OT_statsHUD") displayCtrl 1001;
_setText ctrlSetStructuredText (parseText format ["%1", _txt]);
_setText ctrlCommit 0;

[OT_fnc_statsSystemLoop, _this, 1] call CBA_fnc_waitAndExecute;
