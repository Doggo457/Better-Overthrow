params ["_objective", "_strength"];
private _posTown = getMarkerPos _objective;

private _tskid = [independent, [format ["counter%1", _objective]], [format ["NATO is sending forces to %1. This is our chance to capture it if we can hold the field.", _objective], format ["Capture %1", _objective], format ["counter%1", _objective]], _posTown, 1, 2, true, "Target", true] call BIS_fnc_taskCreate;

format ["NATO is attacking %1", _objective] remoteExec ["OT_fnc_notifyMinor", 0, false];

private _fail = {
    params ["_tskid", "_objective"];
    [_tskid, "SUCCEEDED", true] spawn BIS_fnc_taskSetState;
    _objective setMarkerType OT_flagMarker;

    private _effect = "";
    if (_objective isEqualTo "The Fuel Depot") then {
        _effect = "(Vehicles are now cheaper)";
    };
    format ["Resistance has captured %1 (+100 Influence) %2", _objective, _effect] remoteExec ["OT_fnc_notifyGood", 0, false];
    100 remoteExec ["OT_fnc_influenceSilent", 0, false];
    private _posTown = getMarkerPos _objective;
    private _flag = _posTown nearObjects [OT_flag_NATO, 500];
    if (_flag isNotEqualTo []) then {
        deleteVehicle (_flag select 0);
    };
    private _abandoned = server getVariable "NATOabandoned";
    _abandoned pushBack _objective;
    server setVariable ["NATOabandoned", _abandoned, true];
    format ["%1_restrict", _objective] setMarkerAlpha 0;
};

private _success = {
    params ["_tskid", "_objective"];
    //NATO has won
    [_tskid, "FAILED", true] spawn BIS_fnc_taskSetState;
    private _abandoned = server getVariable "NATOabandoned";
    _abandoned deleteAt (_abandoned find _objective);
    server setVariable ["NATOabandoned", _abandoned, true];
    server setVariable [format ["garrison%1", _objective], round (8 + random 12), true];
    // BO: drop the persisted garrison layout -- NATO has reinforced
    // and repositioned, so the next spawn should roll a fresh layout.
    [_objective] call BO_fnc_clearReconState;
};

[_posTown, _strength, _success, _fail, [_tskid, _objective], _objective] spawn OT_fnc_NATOQRF;
