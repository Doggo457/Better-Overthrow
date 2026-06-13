#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_evaluateOp
 *
 * Per-tick status machine for one active op. v2 full engine: arrival /
 * dismount transitions, recon observe->exfil, reinforce / retreat with
 * win-prob (build doc section 8), retreat-cascade progression (locked
 * #13), garrisoned refund deferral, timeout recycling.
 *
 * Statuses:
 *   transit -> active (combat) | observing (recon)
 *   active -> retreating (cascade) | done (timeout/objective)
 *   observing -> exfil -> done
 *   retreating -> extracting -> garrisoned/committed/done
 *   fading -> done (when no player is left watching)
 *
 * Params: 0: ARRAY op record (mutated in place)
 */

SERVER_ONLY;
params [["_op", [], [[]]]];
if (_op isEqualTo []) exitWith {};
_op params ["_opId", "_pkgId", "_grp", "_veh", "_crewGrp", "_tgt", "_origin",
            "_launch", "_status", "_initial", "_reinf", "_cost", "_kind", "_stamp", "_data"];

private _now = serverTime;

// Group wiped (or never spawned): close out. Field groups are world
// property -- drop the record, never run delete/refund machinery.
private _aliveInf = if (isNull _grp) then { 0 } else { { alive _x } count units _grp };
if (_aliveInf isEqualTo 0 && {_status isNotEqualTo "fading"}) exitWith {
    if (_kind isEqualTo "field") then {
        private _idx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _opId };
        if (_idx >= 0) then { BO_HAL_activeOps deleteAt _idx };
        ["field_wiped", [_opId]] call BO_HAL_fnc_aar;
    } else {
        [_op, false, "wiped"] call BO_HAL_fnc_recycleOp;
    };
};

private _lead = leader _grp;
private _engaged = ((units _grp) findIf {
    alive _x && {
        private _e = _x findNearestEnemy _x;
        !isNull _e && { _x knowsAbout _e > 2.5 }
    }
}) != -1;

// Casualty tracking: knowsAbout misses unseen shooters (a sniper can
// bleed a squad dry without ever tripping the "engaged" test, so they
// stood and died). A recent loss counts as being under fire.
private _lastAlive = _grp getVariable ["BO_HAL_lastAlive", _aliveInf];
if (_aliveInf < _lastAlive) then {
    _grp setVariable ["BO_HAL_lastLoss", _now, false];
};
_grp setVariable ["BO_HAL_lastAlive", _aliveInf, false];
private _underFire = _engaged || {(_now - (_grp getVariable ["BO_HAL_lastLoss", -1e7])) < 180};

// Disabled-aircraft bail-out (RPT/playtest finding: rotor shot off on
// landing -> crew sat in the wreck forever). A flightless bird with a
// living crew is ABANDONED: everyone out, both groups walk for the
// origin base, op flips to exfil -- which on arrival recycles with the
// standard survivors-formula refund, pilots included.
if (!isNull _veh && {alive _veh} && {_veh isKindOf "Air"} && {!canMove _veh}
    && {_status in ["transit", "active", "observing", "retreating", "extracting"]}
    && {!(_grp getVariable ["BO_HAL_airBailed", false])}
    && {((crew _veh) findIf { alive _x }) != -1}) then {
    _grp setVariable ["BO_HAL_airBailed", true, false];
    { unassignVehicle _x; moveOut _x } forEach ((crew _veh) select { alive _x });
    {
        private _g = _x;
        if (!isNull _g && {({ alive _x } count units _g) > 0}) then {
            _g setBehaviour "AWARE";
            _g setCombatMode "YELLOW";
            _g setSpeedMode "FULL";
            while { count waypoints _g > 0 } do { deleteWaypoint [_g, 0] };
            private _wpb = _g addWaypoint [_origin, 0];
            _wpb setWaypointType "MOVE";
            _wpb setWaypointCompletionRadius 50;
        };
    } forEach [_grp, _crewGrp];
    // The wreck is no longer the op's ride; recycle still deletes it
    // via the op record when the area is clear.
    _op set [8, "exfil"];
    _op set [13, _now];
    ["air_bail", [_opId, _pkgId]] call BO_HAL_fnc_aar;
};

switch (_status) do {

    // ------------------------------------------------------------------
    case "transit": {
        // Hard timeout: 1800s without reaching the AO. HAL-spawned ops
        // recycle (with refund); adopted field groups are released.
        if ((_now - _launch) > 1800 && {!_engaged}) exitWith {
            if (_kind isEqualTo "field") then {
                [_op, "transit_timeout"] call BO_HAL_fnc_releaseFieldGroup;
            } else {
                [_op, true, "transit_timeout"] call BO_HAL_fnc_recycleOp;
            };
        };

        // Garrison convoy arrival: fold into the snapshot when the base
        // is despawned and unwatched, otherwise dismount and join the
        // live garrison. Either way HAL's job ends here (exitWith at
        // case scope -- nothing below may touch the handed-off group).
        if (_kind isEqualTo "garrisonReinforce" && {!_engaged} && {
            private _gref = if (!isNull _veh && {alive _veh}) then { _veh } else { _lead };
            (_gref distance2D _tgt) < 320
        }) exitWith {
            private _base = _data param [0, ""];
            private _snapExists = (server getVariable [format ["BO_reconLayout_%1", _base], []]) isNotEqualTo [];
            private _playerNear = ((allPlayers select { alive _x }) findIf {
                (_x distance2D _tgt) < OT_spawnDistance
            }) != -1;
            private _serialized = _snapExists && {!_playerNear};
            private _added = if (_serialized) then {
                [_base, _tgt, _grp, _veh, _crewGrp] call BO_HAL_fnc_garrisonSerialize
            } else {
                [_base, _tgt, _grp, _veh, _crewGrp] call BO_HAL_fnc_garrisonLiveJoin
            };
            private _gidx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _opId };
            if (_gidx >= 0) then { BO_HAL_activeOps deleteAt _gidx };
            ["garrison_arrived", [_opId, _base, _added, _serialized]] call BO_HAL_fnc_aar;
        };

        // Contact during transit promotes straight to active --
        // including unattributed losses (ambush by an unseen shooter).
        if (_underFire) exitWith {
            if (!isNull _veh && {(units _grp) findIf { vehicle _x isEqualTo _veh } != -1}) then {
                { unassignVehicle _x; if (vehicle _x isNotEqualTo _x) then { _x action ["GetOut", vehicle _x] } } forEach (units _grp);
            };
            _grp setCombatMode "YELLOW";
            _grp setBehaviour "COMBAT";
            // Crew drops the CARELESS transit posture the moment the
            // op is in contact.
            if (!isNull _crewGrp) then { _crewGrp setBehaviour "AWARE" };
            _op set [8, "active"];
            _op set [13, _now];
        };

        // Arrival at dismount range.
        private _ref = if (!isNull _veh && {alive _veh}) then { _veh } else { _lead };
        if ((_ref distance2D _tgt) < 420) then {
            // Heliborne ops land first: order the touchdown, unload once
            // the skids are low (20s ceiling), then send the helo home --
            // it waits at its origin base and despawns with the op. The
            // generic ground dismount below is GATED on !_heloDrop, or it
            // would GetOut the squad at altitude.
            private _heloDrop = !isNull _veh && {alive _veh} && {_veh isKindOf "Helicopter"}
                && {((units _grp) findIf { vehicle _x isEqualTo _veh }) != -1};
            if (_heloDrop) then {
                _veh land "GET OUT";
                [
                    { params ["_v"]; isNull _v || {!alive _v} || {((getPosATL _v) select 2) < 4} },
                    {
                        params ["_v", "_g", "_cg", "_home"];
                        if (isNull _v || {!alive _v}) exitWith {};
                        { unassignVehicle _x; _x action ["GetOut", _v] } forEach
                            ((units _g) select { vehicle _x isEqualTo _v });
                        // RTB after the drop.
                        if (!isNull _cg) then {
                            while { count waypoints _cg > 0 } do { deleteWaypoint [_cg, 0] };
                            private _wpr = _cg addWaypoint [_home, 0];
                            _wpr setWaypointType "MOVE";
                            _wpr setWaypointCompletionRadius 150;
                        };
                    },
                    [_veh, _grp, _crewGrp, +_origin], 20,
                    {
                        params ["_v", "_g"];
                        if (!isNull _v && {alive _v}) then {
                            { unassignVehicle _x; _x action ["GetOut", _v] } forEach
                                ((units _g) select { vehicle _x isEqualTo _v });
                        };
                    }
                ] call CBA_fnc_waitUntilAndExecute;
            };
            if (!isNull _veh && {!_heloDrop}) then {
                { unassignVehicle _x; if (vehicle _x isNotEqualTo _x) then { _x action ["GetOut", vehicle _x] } } forEach (units _grp);
                // Crew holds nearby as the casevac/fire-support element
                // -- and drops the CARELESS transit posture.
                if (!isNull _crewGrp) then {
                    _crewGrp setBehaviour "AWARE";
                    while { count waypoints _crewGrp > 0 } do { deleteWaypoint [_crewGrp, 0] };
                    private _wpc = _crewGrp addWaypoint [_tgt getPos [300, _tgt getDir _origin], 0];
                    _wpc setWaypointType "MOVE";
                    _wpc setWaypointCompletionRadius 40;
                };
            };
            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
            if (_kind in ["recon", "fob"]) then {
                // Overwatch point short of the objective; never engage.
                private _ow = _tgt getPos [250 + random 100, _tgt getDir _origin];
                private _wp = _grp addWaypoint [_ow, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointCompletionRadius 30;
                _grp setSpeedMode "LIMITED";
                _op set [8, "observing"];
            } else {
                private _wp = _grp addWaypoint [_tgt getPos [40, random 360], 0];
                _wp setWaypointType (["MOVE", "SAD"] select (_kind isEqualTo "hunter"));
                _wp setWaypointCompletionRadius 15;
                _grp setBehaviour "COMBAT";
                _op set [8, "active"];
            };
            _op set [13, _now];
        };

        // Reinforce-kind: fold into parent when close.
        if (_kind isEqualTo "reinforce") then {
            private _parentId = _data param [0, -1];
            private _pIdx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _parentId };
            if (_pIdx < 0) exitWith {
                // Parent gone: behave as a normal light op.
                _op set [12, "hot"];
            };
            private _parent = BO_HAL_activeOps select _pIdx;
            private _pGrp = _parent select 2;
            if (!isNull _pGrp && {(_lead distance2D (leader _pGrp)) < 200}) then {
                (units _grp) joinSilent _pGrp;
                _parent set [9, (_parent select 9) + _aliveInf];
                [_op, false, "merged"] call BO_HAL_fnc_recycleOp;
            };
        };
    };

    // ------------------------------------------------------------------
    case "active": {
        // V2 retreat / reinforce thresholds (build doc section 8;
        // retreat raised 0.4 -> 0.5 and keyed to underFire after the
        // first live sessions showed squads standing and dying to
        // shooters they never "knowsAbout"-registered).
        private _strength = _grp getVariable ["initialStrength", _initial max 1];
        private _ratio = _aliveInf / (_strength max 1);

        // Garrison convoys fight through ambushes: once contact ends,
        // remount (if the ride lives) and resume the delivery.
        if (_kind isEqualTo "garrisonReinforce" && {!_engaged} && {(_now - _stamp) > 180}) exitWith {
            if (!isNull _veh && {alive _veh} && {canMove _veh}) then {
                { _x assignAsCargo _veh; _x orderGetIn true } forEach (units _grp select { vehicle _x isEqualTo _x });
                if (!isNull _crewGrp) then {
                    while { count waypoints _crewGrp > 0 } do { deleteWaypoint [_crewGrp, 0] };
                    private _wpc = _crewGrp addWaypoint [_tgt getPos [250, _tgt getDir _origin], 0];
                    _wpc setWaypointType "MOVE";
                    _wpc setWaypointSpeed "FULL";
                };
            } else {
                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                private _wpg = _grp addWaypoint [_tgt, 0];
                _wpg setWaypointType "MOVE";
            };
            _op set [8, "transit"];
            _op set [13, _now];
            ["garrison_resume", [_opId]] call BO_HAL_fnc_aar;
        };

        // Retreat at 60% strength under fire (raised from 50% -- small
        // teams were getting wiped between evals before ever reaching
        // the threshold). Counter-doctrine: against a marksman campaign
        // the threshold climbs to 75% -- bleeding to a rifle you can't
        // see is exactly when you break early.
        (missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]])
            params [["_tSniper", 0], "", "", "", "", "", ["_tSwarm", 0]];
        private _retreatAt = (0.6 + 0.15 * _tSniper) min 0.75;
        if (_ratio < _retreatAt && {_underFire}) exitWith {
            // All-UAV groups never run the ground cascade -- a wounded
            // drone just gets recycled with the standard refund.
            if (((units _grp) findIf { !unitIsUAV _x }) == -1) exitWith {
                [_op, true, "drone_withdrawn"] call BO_HAL_fnc_recycleOp;
            };
            switch (_kind) do {
                case "field": {
                    // Regulars break contact and go home -- no transport
                    // cascade spend on units HAL didn't pay for.
                    [_grp, _tgt] call BO_HAL_fnc_breakContact;
                    [_op, "retreat"] call BO_HAL_fnc_releaseFieldGroup;
                };
                case "garrisonReinforce": {
                    // Mauled convoy aborts the delivery: limp home, then
                    // the exfil path recycles with the 0.7 refund.
                    [_grp, _tgt] call BO_HAL_fnc_breakContact;
                    private _wph = _grp addWaypoint [_origin, 1];
                    _wph setWaypointType "MOVE";
                    _op set [8, "exfil"];
                    _op set [13, _now];
                    ["garrison_abort", [_opId]] call BO_HAL_fnc_aar;
                };
                default {
                    [_op] call BO_HAL_fnc_retreatCascade;
                };
            };
        };

        if (_ratio >= _retreatAt && {_ratio <= 0.85} && {_underFire} && {_reinf < 2}) then {
            private _winProb = [_grp, _tgt] call BO_HAL_fnc_estimateWinProb;
            // Counter-doctrine: against massed rebels NATO commits to
            // fights it would otherwise walk away from.
            if (_winProb >= (0.45 - 0.1 * _tSwarm) && {(server getVariable ["NATOresources", 0]) >= 80}) then {
                if ([_op] call BO_HAL_fnc_reinforceVariant) then {
                    _op set [10, _reinf + 1];
                };
            };
        };

        // RTB on dry tanks / dry guns (user-locked): a vehicle below 15%
        // fuel, or an ARMED vehicle that has shot itself empty, takes
        // the whole op home when contact allows -- arrival at the origin
        // base recycles with the survivors-formula refund instead of
        // loitering until the timeout eats the budget.
        if (!_underFire && {!isNull _veh} && {alive _veh}
            && {(fuel _veh < 0.15) || {(count weapons _veh > 0) && {!someAmmo _veh}}}) exitWith {
            {
                private _g = _x;
                if (!isNull _g && {({ alive _x } count units _g) > 0}) then {
                    while { count waypoints _g > 0 } do { deleteWaypoint [_g, 0] };
                    private _wpr = _g addWaypoint [_origin, 0];
                    _wpr setWaypointType "MOVE";
                    _wpr setWaypointCompletionRadius 50;
                    _g setSpeedMode "FULL";
                };
            } forEach [_grp, _crewGrp];
            // Ground crews remount their ride for the drive home.
            if (!(_veh isKindOf "Air")) then {
                { _x assignAsCargo _veh; _x orderGetIn true } forEach
                    ((units _grp) select { alive _x && { vehicle _x isEqualTo _x } });
            };
            _op set [8, "exfil"];
            _op set [13, _now];
            ["rtb_resupply", [_opId, _pkgId, round (fuel _veh * 100)]] call BO_HAL_fnc_aar;
        };

        // Interdiction resolution: the ambush op races the delivery
        // clock (already extended once at launch). Both outcomes exit
        // at CASE scope -- nothing below may touch a recycled op.
        if (_kind isEqualTo "interdiction" && {
            private _dId = _data param [0, ""];
            ((server getVariable ["BO_logisticsActiveDeliveries", []]) findIf {
                (_x select 0) isEqualTo _dId
            }) < 0
        }) exitWith {
            // Delivery already resolved (arrived on the extended clock,
            // or the player's logistics state changed): pack up.
            [_op, true, "interdict_over"] call BO_HAL_fnc_recycleOp;
        };
        if (_kind isEqualTo "interdiction") then {
            private _dId = _data param [0, ""];
            private _deliveries = server getVariable ["BO_logisticsActiveDeliveries", []];
            private _dIdx = _deliveries findIf { (_x select 0) isEqualTo _dId };
            if (_dIdx >= 0 && {_now > ((_deliveries select _dIdx) select 3)}) then {
                // Ambush still standing at the extended ETA: the convoy
                // is lost -- cargo returns to the SOURCE warehouse
                // (logisticsArrive applies the payload to whatever the
                // dst slot resolves to, so point it back at the source).
                private _delivery = _deliveries select _dIdx;
                _deliveries deleteAt _dIdx;
                server setVariable ["BO_logisticsActiveDeliveries", _deliveries, true];
                private _back = +_delivery;
                _back set [6, _delivery select 5]; // dstId := srcId
                [_back] call BO_fnc_logisticsArrive;
                private _routes = server getVariable ["BO_logisticsRoutes", []];
                private _rIdx = _routes findIf { (_x select 0) isEqualTo (_delivery select 1) };
                if (_rIdx >= 0) then {
                    private _route = _routes select _rIdx;
                    private _stats = _route param [9, [0, 0, ""]];
                    _stats set [2, "convoy lost -- cargo returned to source"];
                    _route set [9, _stats];
                    server setVariable ["BO_logisticsRoutes", _routes, true];
                };
                ["interdict_success", [_opId, _dId]] call BO_HAL_fnc_aar;
                _data set [0, "__resolved__"]; // next pass exits via the
                                               // delivery-gone branch
            };
        };

        // Objective lifetime: 1800s engaged-or-not, then wind down.
        if ((_now - _stamp) > 1800 && {!_engaged}) then {
            if (_kind isEqualTo "field") then {
                [_op, "op_complete"] call BO_HAL_fnc_releaseFieldGroup;
            } else {
                [_op, true, "op_complete"] call BO_HAL_fnc_recycleOp;
            };
        };
    };

    // ------------------------------------------------------------------
    case "observing": {
        // Scouts confirm you exist, then leave without firing (north
        // star). 180-300s on station.
        private _dwell = _data param [1, -1];
        if (_dwell < 0) then {
            _op set [14, [_data param [0, -1], 180 + random 120]];
            _dwell = 999;
        };
        if (_engaged) exitWith {
            // Recon compromised: immediate exfil, and the sighting goes hot.
            [_grp, getPosATL _lead] call BO_HAL_fnc_breakContact;
            _op set [8, "exfil"];
            _op set [13, _now];
        };
        if ((_now - _stamp) > (_data param [1, 240])) then {
            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
            private _wp = _grp addWaypoint [_origin, 0];
            _wp setWaypointType "MOVE";
            _grp setSpeedMode "FULL";
            // Remount if the ride still exists.
            if (!isNull _veh && {alive _veh}) then {
                { _x assignAsCargo _veh; _x orderGetIn true } forEach (units _grp);
                if (!isNull _crewGrp) then {
                    while { count waypoints _crewGrp > 0 } do { deleteWaypoint [_crewGrp, 0] };
                    private _wpc = _crewGrp addWaypoint [_origin, 0];
                    _wpc setWaypointType "MOVE";
                };
            };
            _op set [8, "exfil"];
            _op set [13, _now];
            ["recon_exfil", [_opId, _pkgId]] call BO_HAL_fnc_aar;
        };
    };

    // ------------------------------------------------------------------
    case "exfil": {
        if ((_lead distance2D _origin) < 300 || {(_now - _stamp) > 1200}) then {
            [_op, true, "exfil_complete"] call BO_HAL_fnc_recycleOp;
        };
    };

    // ------------------------------------------------------------------
    case "retreating": {
        _data params [["_dest", [0,0,0]], ["_destKind", "base"], ["_trans", objNull], ["_transCrew", grpNull], ["_rally", [0,0,0]], ["_deadline", -1]];

        // No transport (faction had none): leg it -> extracting handled below.
        if (isNull _trans) exitWith {
            _op set [8, "extracting"];
            _op set [13, _now];
        };

        // Transport killed before pickup: survivors are stranded.
        // Locked #13: despawned, NO refund -- the player's reward for
        // cutting the extraction.
        if (!alive _trans) exitWith {
            ["retreat_transport_lost", [_opId]] call BO_HAL_fnc_aar;
            [_op, false, "stranded"] call BO_HAL_fnc_recycleOp;
        };

        private _dismounted = (units _grp) select { alive _x && { vehicle _x isEqualTo _x } };

        // Transport reached the rally: load up (90s pickup window).
        if ((_trans distance2D (leader _grp)) < 120) then {
            if (_deadline < 0) then {
                _deadline = _now + 90;
                _data set [5, _deadline];
                { _x assignAsCargo _trans; _x orderGetIn true } forEach _dismounted;
            };
            private _aboard = { vehicle _x isEqualTo _trans } count (units _grp);
            if (_aboard >= count (units _grp select { alive _x }) || {_now > _deadline}) then {
                // Stragglers not aboard at the deadline are left behind
                // (despawn out of player sight, no refund for them).
                {
                    if (vehicle _x isEqualTo _x) then {
                        if (((allPlayers select { alive _x }) findIf { (_x distance2D _lead) < 600 }) == -1) then {
                            deleteVehicle _x;
                        };
                    };
                } forEach _dismounted;
                if (!isNull _transCrew) then {
                    while { count waypoints _transCrew > 0 } do { deleteWaypoint [_transCrew, 0] };
                    private _wp = _transCrew addWaypoint [_dest, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "FULL";
                };
                _op set [8, "extracting"];
                _op set [13, _now];
            };
        };

        // Pickup stuck for 6+ minutes: give up, leg it.
        if ((_now - _stamp) > 360 && {(_trans distance2D (leader _grp)) >= 120}) then {
            _op set [8, "extracting"];
            _op set [13, _now];
        };
    };

    // ------------------------------------------------------------------
    case "extracting": {
        _data params [["_dest", [0,0,0]], ["_destKind", "base"], ["_trans", objNull], ["_transCrew", grpNull]];
        private _ref = if (!isNull _trans && {alive _trans}) then { _trans } else { _lead };

        if ((_ref distance2D _dest) < 250 || {(_now - _stamp) > 1800}) then {
            switch (_destKind) do {
                case "lastgasp": {
                    // Committed: no refund, group fights at the town until wiped.
                    _op set [8, "committed"];
                    _op set [13, _now];
                    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                    private _wp = _grp addWaypoint [_dest, 0];
                    _wp setWaypointType "SAD";
                };
                default {
                    // Base/town arrival: the refund lands IMMEDIATELY --
                    // survivors are home, NATO recovers the budget now.
                    // Only the physical despawn defers while a player is
                    // watching (recycleOp handles that; refund=false so
                    // it can't double-pay on the deferred retry).
                    private _living = { alive _x } count units _grp;
                    if (_initial > 0 && {!(_data param [4, false] isEqualTo true)}) then {
                        private _amount = round ((_living / _initial) * _cost * 0.7);
                        if (_amount > 0) then {
                            server setVariable ["NATOresources",
                                (server getVariable ["NATOresources", 0]) + _amount, true];
                            ["refund", [_opId, _amount]] call BO_HAL_fnc_aar;
                        };
                        // Flag on the op data so a deferred recycle pass
                        // never refunds twice.
                        if (count _data > 4) then { _data set [4, true] } else {
                            while { count _data < 4 } do { _data pushBack nil };
                            _data pushBack true;
                        };
                    };
                    [_op, false, "retreat_complete"] call BO_HAL_fnc_recycleOp;
                };
            };
        };
    };

    // ------------------------------------------------------------------
    case "committed": {
        // NATO's last lunge: runs until wiped (the wipe check at the top
        // closes it). Re-issue SAD if the group went idle.
        if (count waypoints _grp isEqualTo 0) then {
            private _wp = _grp addWaypoint [_tgt, 0];
            _wp setWaypointType "SAD";
        };
    };

    // ------------------------------------------------------------------
    case "fading": {
        // Deferred deletion: retry once the player has left, honoring
        // the refund intent recycleOp stashed when it deferred.
        [_op, _data param [0, false], _data param [1, "faded"]] call BO_HAL_fnc_recycleOp;
    };

    default {};
};
