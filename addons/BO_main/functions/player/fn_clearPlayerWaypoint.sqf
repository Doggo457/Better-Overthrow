OT_missionMarker = nil;
while { (waypoints group player) isNotEqualTo [] } do {
    deleteWaypoint ((waypoints group player) select 0);
};
