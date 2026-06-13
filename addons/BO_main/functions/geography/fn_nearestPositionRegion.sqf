params ["_things", "_origin", "_region"];

private _ret = [];
{

    if (_x inArea _region) then {
        _ret pushBack _x;
    };
} forEach (_things);

[_ret, _origin] call BIS_fnc_nearestPosition;
