private _pos = _this;
([server getVariable ["activemobsters", []], [], { (_x select 0) distance _pos }, "ASCEND"] call BIS_fnc_sortBy) select 0;
