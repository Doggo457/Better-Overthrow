private _region = _this select 0;

private _ret = [];
{
    private _p = server getVariable _x;
    if (_p inArea _region) then {
        _ret pushBack _x;
    };
} forEach (OT_allTowns);

_ret;
