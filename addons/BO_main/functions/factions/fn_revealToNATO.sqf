params ["_unit", ["_dis", 800]];

// BO HAL hook: revealToNATO is the chokepoint every "NATO saw you"
// path funnels through (wantedLoop, tagging, cargo, vehicle sabotage).
// One guarded line (JIP race protection per build doc section 5).
if (!isNil "BO_HAL_fnc_ingestSighting") then {
    [_unit, [], "reveal"] call BO_HAL_fnc_ingestSighting;
};

{
    if (side _x isEqualTo blufor && (units _x isNotEqualTo [])) then {
        private _lead = leader _x;
        if ((_lead distance2D _unit) < _dis) then {
            _lead reveal [_unit, 1.5];
        };
    };
} forEach (groups blufor);
