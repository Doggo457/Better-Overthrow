if (!isServer) exitWith {};
sleep random 0.2;

params ["_town", "_spawnid"];
private _abandoned = server getVariable ["NATOabandoned", []];
if !(_town in _abandoned) exitWith {};

private _posTown = server getVariable [format ["policepos%1", _town], server getVariable _town];

private _groups = [];

private _soldier = "Police" call OT_fnc_getSoldier;

private _numNATO = server getVariable [format ["police%1", _town], 0];
private _count = 0;
private _range = 15;
private _pergroup = 4;

while { _count < _numNATO } do {
    private _groupcount = 0;
    private _group = createGroup independent;
    _group setVariable ["VCM_TOUGHSQUAD", true, true];
    _group setVariable ["VCM_NORESCUE", true, true];
    _groups pushBack _group;

    private _start = [[[_posTown, _range]]] call BIS_fnc_randomPos;

    while { (_groupcount < _pergroup) && (_count < _numNATO) } do {
        private _pos = [[[_start, 20]]] call BIS_fnc_randomPos;

        private _civ = [_soldier, _pos, _group, false] call OT_fnc_createSoldier;
        sleep 0.3;

        [_civ] joinSilent _group;
        _civ setRank "SERGEANT";
        [_civ, _town] spawn OT_fnc_initPolice;
        _civ setBehaviour "SAFE";

        _groupcount = _groupcount + 1;
        _count = _count + 1;
        sleep 0.5;
    };
    [_group, _posTown, 100, 6] call CBA_fnc_taskPatrol;
    _range = _range + 50;
};

spawner setVariable [_spawnid, (spawner getVariable [_spawnid, []]) + _groups, false];
