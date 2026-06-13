private _group = _this;

private _town = server getVariable ((leader _group) getVariable "polgarrison");
if (isNil "_town") then { _town = getPos (leader _group) };
private _start = getPos (leader _group);

_group setVariable ["VCM_NORESCUE", true];
_group setVariable ["VCM_TOUGHSQUAD", true];

private _dest = _town call OT_fnc_getRandomRoadPosition;

private _wp = _group addWaypoint [_dest, 5];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";
_wp setWaypointTimeout [10, 20, 60];

_dest = _town call OT_fnc_getRandomRoadPosition;

_wp = _group addWaypoint [_dest, 10];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";
_wp setWaypointTimeout [10, 20, 60];

_dest = _town call OT_fnc_getRandomRoadPosition;

_wp = _group addWaypoint [_dest, 10];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";
_wp setWaypointTimeout [10, 20, 60];

_dest = _town call OT_fnc_getRandomRoadPosition;

_wp = _group addWaypoint [_dest, 10];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";
_wp setWaypointTimeout [10, 20, 60];

_dest = _town call OT_fnc_getRandomRoadPosition;

_wp = _group addWaypoint [_dest, 10];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";
_wp setWaypointTimeout [10, 20, 60];

_wp = _group addWaypoint [_start, 5];
_wp setWaypointType "CYCLE";
