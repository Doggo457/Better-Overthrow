#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_fieldCommand
 *
 * The all-NATO command pass (60s PFH). HAL doesn't just spawn its own
 * packages -- it commands the standing army:
 *
 *   GARRISONS (units tagged `garrison = <name>` by OT's spawners, or
 *   groups HAL has folded into a base) DEFEND IN PLACE: a leash keeps
 *   them within BO_HAL_garrisonLeash of their anchor. They're recalled
 *   only when NOT engaged and NO enemy is near the base -- chasing a
 *   visible attacker off the wire is defending; wandering to the next
 *   town is not.
 *
 *   FIELD GROUPS (leftover QRFs, patrols, dismounted survivors) join
 *   BO_HAL_fieldPool, HAL's free response pool -- the hot branch tasks
 *   the nearest pool group before paying to spawn a fresh package.
 *   A group idle for 10+ minutes is consolidated: marched to the
 *   nearest NATO objective and folded into its garrison (tagged
 *   `garrison`, so it also joins BO's persistent-garrison snapshots).
 *
 * Out of scope, deliberately: air groups (OT's scrambles own them),
 * static gunners (already defending), UAV crews, players, and HAL's
 * own op groups.
 */

SERVER_ONLY;
if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};
if (!(missionNamespace getVariable ["BO_HAL_commandAll", true])) exitWith {};

private _now = serverTime;
private _leash = missionNamespace getVariable ["BO_HAL_garrisonLeash", 300];
private _pool = missionNamespace getVariable ["BO_HAL_fieldPool", []];

// Prune the pool of dead/empty groups.
_pool = _pool select {
    !isNull _x && {({ alive _x } count units _x) > 0}
};

{
    private _grp = _x;
    private _units = units _grp select { alive _x };

    if (_units isNotEqualTo []) then {
        private _lead = leader _grp;

        // ---- exclusions --------------------------------------------------
        private _skip = (_units findIf { isPlayer _x }) != -1;
        if (!_skip && {!isNil { _grp getVariable "BO_HAL_op" }}) then { _skip = true };
        if (!_skip && {vehicle _lead isKindOf "Air"}) then { _skip = true };
        if (!_skip && {(_units findIf { unitIsUAV _x }) != -1}) then { _skip = true };
        // Skip groups whose every man is crewed into a static weapon.
        if (!_skip && {(_units findIf { !((vehicle _x) isKindOf "StaticWeapon") }) == -1}) then { _skip = true };

        if (!_skip) then {
            // ---- first contact: stamp anchor + role ----------------------
            if (isNil { _grp getVariable "BO_HAL_seenAt" }) then {
                _grp setVariable ["BO_HAL_seenAt", _now, false];
                _grp setVariable ["BO_HAL_anchor", getPosATL _lead, false];
                private _isGarrison = (_units findIf {
                    !isNil { _x getVariable "garrison" } || {!isNil { (vehicle _x) getVariable "garrison" }}
                }) != -1;
                _grp setVariable ["BO_HAL_role", ["field", "garrison"] select _isGarrison, false];
            };

            private _role = _grp getVariable ["BO_HAL_role", "field"];
            private _anchor = _grp getVariable ["BO_HAL_anchor", getPosATL _lead];

            switch (_role) do {

                // ---- garrison: defend in place ----------------------------
                case "garrison": {
                    if ((_now - (_grp getVariable ["BO_HAL_leashCheck", 0])) > 120) then {
                        _grp setVariable ["BO_HAL_leashCheck", _now, false];
                        if (((getPosATL _lead) distance2D _anchor) > _leash) then {
                            private _enemy = _lead findNearestEnemy _lead;
                            private _engaged = !isNull _enemy && {(_lead knowsAbout _enemy) > 1.5};
                            private _baseThreat = ((_anchor nearEntities [["CAManBase"], 500]) findIf {
                                side group _x isEqualTo independent && {!captive _x} && {alive _x}
                            }) != -1;
                            // Chasing someone off the wire is defending;
                            // wandering the map is not. Recall when calm.
                            if (!_engaged && {!_baseThreat}) then {
                                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                                private _wp = _grp addWaypoint [_anchor, 0];
                                _wp setWaypointType "MOVE";
                                _wp setWaypointCompletionRadius 30;
                                _grp setSpeedMode "NORMAL";
                                ["garrison_recall", [groupId _grp, round ((getPosATL _lead) distance2D _anchor)]] call BO_HAL_fnc_aar;
                            };
                        };
                    };
                };

                // ---- rtb: marching home to fold into a garrison -----------
                case "rtb": {
                    private _dest = _grp getVariable ["BO_HAL_rtbDest", []];
                    private _dname = _grp getVariable ["BO_HAL_rtbName", ""];
                    if (_dest isEqualTo []) then {
                        _grp setVariable ["BO_HAL_role", "field", false];
                    } else {
                        if (((getPosATL _lead) distance2D _dest) < 120) then {
                            // Arrived: become garrison (joins BO's persistent
                            // garrison snapshots via the `garrison` tag).
                            { _x setVariable ["garrison", _dname, false] } forEach _units;
                            _grp setVariable ["BO_HAL_role", "garrison", false];
                            _grp setVariable ["BO_HAL_anchor", +_dest, false];
                            private _pi = _pool find _grp;
                            if (_pi >= 0) then { _pool deleteAt _pi };
                            ["field_consolidated", [groupId _grp, _dname]] call BO_HAL_fnc_aar;
                        };
                    };
                };

                // ---- field: adopt + consolidate when long-idle ------------
                default {
                    private _idle = (count waypoints _grp isEqualTo 0)
                        || {currentWaypoint _grp >= count waypoints _grp};
                    private _enemy = _lead findNearestEnemy _lead;
                    private _calm = isNull _enemy || {(_lead knowsAbout _enemy) < 1.5};
                    private _cooldown = (_now - (_grp getVariable ["BO_HAL_releasedAt", -1e7])) < 180;
                    private _young = (_now - (_grp getVariable ["BO_HAL_seenAt", _now])) < 180;

                    if (_idle && _calm && {!_cooldown} && {!_young}) then {
                        if (!(_grp in _pool)) then {
                            _pool pushBack _grp;
                            _grp setVariable ["BO_HAL_idleSince", _now, false];
                        };
                        // 10+ min idle: march to the nearest live NATO
                        // objective and reinforce its garrison.
                        if ((_now - (_grp getVariable ["BO_HAL_idleSince", _now])) > 600) then {
                            private _abandoned = server getVariable ["NATOabandoned", []];
                            private _best = [];
                            private _bestName = "";
                            private _bestD = 1e9;
                            {
                                _x params ["_obpos", "_name"];
                                if (!(_name in _abandoned)) then {
                                    private _d = _obpos distance2D _lead;
                                    if (_d < _bestD) then { _bestD = _d; _best = +_obpos; _bestName = _name };
                                };
                            } forEach ((missionNamespace getVariable ["OT_objectiveData", []])
                                + (missionNamespace getVariable ["OT_airportData", []]));
                            if (_best isNotEqualTo []) then {
                                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                                private _wp = _grp addWaypoint [_best, 0];
                                _wp setWaypointType "MOVE";
                                _wp setWaypointCompletionRadius 50;
                                _grp setVariable ["BO_HAL_role", "rtb", false];
                                _grp setVariable ["BO_HAL_rtbDest", _best, false];
                                _grp setVariable ["BO_HAL_rtbName", _bestName, false];
                                ["field_rtb", [groupId _grp, _bestName]] call BO_HAL_fnc_aar;
                            };
                        };
                    } else {
                        // Busy again: reset the idle clock.
                        if (!_idle || {!_calm}) then {
                            _grp setVariable ["BO_HAL_idleSince", _now, false];
                        };
                    };
                };
            };
        };
    };
} forEach (groups west);

missionNamespace setVariable ["BO_HAL_fieldPool", _pool];
