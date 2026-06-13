params ["_target", "_destpos", ["_txt", ""], ["_radius", 5]];

while { (waypoints group _target) isNotEqualTo [] } do {
    deleteWaypoint ((waypoints group _target) select 0);
};
(group _target) addWaypoint [ASLToAGL (getPosASL player), 0];
private _wp = (group player) addWaypoint [_destpos, 15];
OT_missionMarker = _destpos;
OT_missionMarkerText = _txt;

[_target, _radius, _wp] spawn {
    params ["_target", "_radius", "_wp"];
    while { !isNil "_wp" && (player distance waypointPosition _wp) > _radius } do {};
    if (!isNil "_wp") then {
        while { (waypoints group _target) isNotEqualTo [] } do {
            deleteWaypoint ((waypoints group _target) select 0);
        };
        OT_missionMarker = nil;
    };
};

_wp;
