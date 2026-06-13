private _pos = _this;
([server getVariable ["bases", [[[0, 0, 0]]]], [], { (_x select 0) distance2D _pos }, "ASCEND"] call BIS_fnc_sortBy) select 0;
