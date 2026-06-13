private _pos = _this;
([server getVariable ["NATOobjectives", []], [], { (_x select 0) distance2D _pos }, "ASCEND"] call BIS_fnc_sortBy) select 0;
