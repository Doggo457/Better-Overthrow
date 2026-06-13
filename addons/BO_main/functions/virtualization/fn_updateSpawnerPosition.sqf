params ["_changeid", "_start", "_end"];

{
    private _id = _x select 0;
    if (_id isEqualTo _changeid) exitWith {
        _x set [1, _start];
        _x set [2, _end];
    };
} forEach (OT_allSpawners);
