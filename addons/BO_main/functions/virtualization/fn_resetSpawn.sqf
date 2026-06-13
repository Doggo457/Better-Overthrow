private _pars = _this;
{
    private _p = _x select 1;
    if (_p isEqualTo _pars) exitWith {
        private _id = _x select 0;
        OT_allSpawned deleteAt (OT_allSpawned find _id);
    };
} forEach (OT_allSpawners);
