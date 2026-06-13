private _pos = _this select 0;

private _mrkid = format ["%1-whouse", _pos];
createMarkerLocal [_mrkid, _pos];
_mrkid setMarkerShapeLocal "ICON";
_mrkid setMarkerTypeLocal "ot_Warehouse";
_mrkid setMarkerColorLocal "ColorWhite";
_mrkid setMarkerAlpha 1;
