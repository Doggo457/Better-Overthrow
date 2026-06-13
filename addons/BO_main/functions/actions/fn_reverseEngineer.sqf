private _idx = lbCurSel 1500;
private _cls = lbData [1500, _idx];
// The dialog stashes the exact vehicle's netId as the tooltip so we
// resolve the precise object the player selected, rather than
// re-scanning from a stale OT_factoryPos anchor.
private _vehNetId = lbTooltip [1500, _idx];
private _cost = cost getVariable [_cls, []];
private _blueprints = server getVariable ["GEURblueprints", []];
if (_cost isNotEqualTo [] && !(_cls in _blueprints)) then {
    _blueprints pushBack _cls;
    server setVariable ["GEURblueprints", _blueprints, true];
    closeDialog 0;
    "Item is now available for production" call OT_fnc_notifyMinor;

    if (!(_cls isKindOf "Bag_Base") && _cls isKindOf "AllVehicles") then {
        private _veh = objectFromNetId _vehNetId;
        if (isNull _veh) then {
            // Fallback for legacy callers that didn't tag a netId:
            // resolve relative to the interacting factory rather than
            // the frozen map-baked OT_factoryPos. 150m clamp avoids
            // consuming a vehicle at a far-away factory.
            private _factory = OT_interactingWith;
            if (isNull _factory || {(typeOf _factory) != OT_factory}) then {
                _factory = (getPosATL player) nearestObject OT_factory;
                if (!isNull _factory && {(player distance _factory) > 150}) then {
                    _factory = objNull;
                };
            };
            private _anchor = if (isNull _factory) then { OT_factoryPos } else { getPosATL _factory };
            _veh = _anchor nearestObject _cls;
        };
        if (!isNull _veh) then { deleteVehicle _veh };
    } else {
        player removeItem _cls;
    };
} else {
    "Cannot reverse-engineer this item, please contact Overthrow Devs on Discord" call OT_fnc_notifyMinor;
};
