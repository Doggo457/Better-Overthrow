private _pos = _this;
([server getVariable "NATOcomms", [], { (_x select 0) distance2D _pos }, "ASCEND"] call BIS_fnc_sortBy) select 0;
