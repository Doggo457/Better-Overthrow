/*
 * BO mission: Payday Convoy Ambush
 *
 * A NATO payroll convoy moves from one NATO-held town to another. The
 * player has a 30-MINUTE PREP WINDOW after accepting the mission
 * (warning + map marker shown at the origin town) before the convoy
 * actually departs. After deployment the convoy is live-tracked on
 * the map by a marker that follows the transport truck (the cash
 * carrier). Player intercepts and loots the cash crate before the
 * convoy reaches its destination.
 *
 * Phase 1 — Prep (T+0 to T+30 min):
 *   - "Convoy departing in MM:SS" marker pinned at the origin town
 *   - Destination marker shown at the destination town
 *   - No vehicles exist yet — player uses this time to scout the route
 *     and pre-position somewhere on the corridor between the two towns
 *
 * Phase 2 — Active (T+30 min onward, up to 60-min total expiry):
 *   - Prep marker is removed
 *   - Three vehicles spawn at the origin road segment chosen at setup
 *   - "Payday Convoy" tracker marker created at the truck's position
 *   - Tracker marker updates every success poll tick (~2s) to follow
 *     the truck. If the truck is killed, the marker stays at the
 *     last position so the player can find the wreck + crate.
 *
 * Convoy composition (3 vehicles, front-to-back):
 *   - Lead MRAP   : OT_NATO_Vehicles_GroundSupport (fallback MRAP_01_hmg_F)
 *   - Transport   : OT_NATO_Vehicle_Transport      (carries the cash crate)
 *   - Tail MRAP   : OT_NATO_Vehicles_GroundSupport
 *
 * Win condition: any on-foot player within 4m of the crate.
 * Lose condition: lead vehicle reaches destination town (within 100m)
 * still alive after deployment.
 *
 * Reward: $15,000 to the looter's bank (hard tier per PLAN).
 *
 * Wreck cleanup: All vehicles + bodies + the cash crate persist 1hr
 * via BO_fnc_logMissionDebris regardless of outcome. All map markers
 * (prep, destination, tracker) are deleted in the end block.
 */

params ["_jobid", "_jobparams"];

if (isNil "OT_townData" || { OT_townData isEqualTo [] }) exitWith { [] };

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (count _natoTowns < 2) exitWith { [] };

// Find two NATO-held towns within 1.5km of the player. Origin =
// closer of the pair, destination = farther.
private _withinRange = _natoTowns select { ((_x select 0) distance2D player) <= 1500 };
if (count _withinRange < 2) exitWith { [] };

private _sorted = [_withinRange, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _origin = _sorted select 0;
private _destination = _sorted select 1;
_origin params ["_originPos", "_originName"];
_destination params ["_destPos", "_destName"];

// Need at least 600m between origin and dest so the convoy has a
// proper ambush corridor.
if ((_originPos distance2D _destPos) < 600) exitWith { [] };

// Pre-select a road segment near the origin for the eventual spawn.
// We compute this at setup time (not at deployment) so the player
// can scout the road during the prep window.
private _originRoads = (_originPos nearRoads 400) select { _x isKindOf "Road" };
if (_originRoads isEqualTo []) exitWith { [] };

private _midpoint = [(_originPos select 0 + _destPos select 0) / 2, (_originPos select 1 + _destPos select 1) / 2, 0];
private _scored = [_originRoads, [], { (getPos _x) distance2D _midpoint }, "ASCEND"] call BIS_fnc_sortBy;
private _topN = _scored select [0, (5 min count _scored)];
private _spawnRoad = selectRandom _topN;
private _spawnPos = getPos _spawnRoad;
if (_spawnPos isEqualTo [0,0,0]) exitWith { [] };

private _dx = (_destPos select 0) - (_spawnPos select 0);
private _dy = (_destPos select 1) - (_spawnPos select 1);
private _headingToDest = (_dx atan2 _dy);
if (_headingToDest < 0) then { _headingToDest = _headingToDest + 360 };

// Vehicle pools. Faction-aware fallbacks route through the per-map
// Transport_Light single-class so the convoy stays on-faction even
// if the more specific pool isn't populated.
private _mrapPool = if (isNil "OT_NATO_Vehicles_GroundSupport" || { OT_NATO_Vehicles_GroundSupport isEqualTo [] }) then {
    [OT_NATO_Vehicle_Transport_Light]
} else { OT_NATO_Vehicles_GroundSupport };
private _truckPool = if (isNil "OT_NATO_Vehicle_Transport" || { OT_NATO_Vehicle_Transport isEqualTo [] }) then {
    [OT_NATO_Vehicle_Transport_Light]
} else { OT_NATO_Vehicle_Transport };

private _leadClass  = selectRandom _mrapPool;
private _truckClass = selectRandom _truckPool;
private _tailClass  = selectRandom _mrapPool;

private _reward = 15000;
private _prepSeconds = 30 * 60;  // 30 minutes
private _title = format ["Payday Convoy: %1 -> %2", _originName, _destName];
private _description = format [
    "NATO intel says a payroll convoy will depart %1 for %2 in <b>30 minutes</b>. The convoy is three vehicles -- two MRAPs escorting a transport truck carrying the cash crate. Use the prep window to scout the road and pre-position. Once it departs, a live tracker on the map will follow the truck.<br/><br/>Intercept it, kill the escorts, and loot the cash. The cash transfers directly to your bank.<br/><br/>Reward: $%3 (bank deposit) on loot.",
    _originName, _destName, _reward
];

private _params = [_jobid, _spawnPos, _headingToDest, _originPos, _originName, _destPos, _destName, _leadClass, _truckClass, _tailClass, _reward, _prepSeconds];

[
    [_title, _description],
    _originPos,
    {
        params ["_jobid", "_spawnPos", "_headingToDest", "_originPos", "_originName", "_destPos", "_destName", "_leadClass", "_truckClass", "_tailClass", "_reward", "_prepSeconds"];

        // ---- Phase 1 setup: prep markers, no vehicles yet ----
        // The success poll handles the countdown -> deployment trigger
        // -> tracker update. Setup just stamps when the convoy is
        // scheduled to leave and creates the two static markers.

        private _spawnTime = serverTime + _prepSeconds;

        // Prep marker at the origin town -- yellow warning icon with a
        // live MM:SS countdown updated by the success poll.
        private _prepMarker = createMarker [format ["BO_payday_prep_%1", _jobid], _originPos];
        _prepMarker setMarkerType "mil_warning";
        _prepMarker setMarkerColor "ColorRed";
        _prepMarker setMarkerText format ["NATO Payroll Convoy -- departing %1 in 30:00", _originName];
        _prepMarker setMarkerSize [1.2, 1.2];

        // Destination marker -- where the convoy is HEADED. Player
        // sees both ends of the corridor immediately.
        private _destMarker = createMarker [format ["BO_payday_dest_%1", _jobid], _destPos];
        _destMarker setMarkerType "mil_objective";
        _destMarker setMarkerColor "ColorBLUFOR";
        _destMarker setMarkerText format ["Convoy destination: %1", _destName];
        _destMarker setMarkerSize [1.0, 1.0];

        // Stash everything the success poll needs to (a) update the
        // countdown text, (b) spawn the convoy at T-0, and (c) track
        // it on the map afterwards.
        missionNamespace setVariable [format ["BO_payday_spawnTime_%1",  _jobid], _spawnTime];
        missionNamespace setVariable [format ["BO_payday_deployed_%1",   _jobid], false];
        missionNamespace setVariable [format ["BO_payday_spawnPos_%1",   _jobid], _spawnPos];
        missionNamespace setVariable [format ["BO_payday_heading_%1",    _jobid], _headingToDest];
        missionNamespace setVariable [format ["BO_payday_leadClass_%1",  _jobid], _leadClass];
        missionNamespace setVariable [format ["BO_payday_truckClass_%1", _jobid], _truckClass];
        missionNamespace setVariable [format ["BO_payday_tailClass_%1",  _jobid], _tailClass];
        missionNamespace setVariable [format ["BO_payday_originName_%1", _jobid], _originName];
        missionNamespace setVariable [format ["BO_payday_destPos_%1",    _jobid], _destPos];
        missionNamespace setVariable [format ["BO_payday_lead_%1",       _jobid], objNull];
        missionNamespace setVariable [format ["BO_payday_truck_%1",      _jobid], objNull];
        missionNamespace setVariable [format ["BO_payday_tail_%1",       _jobid], objNull];
        missionNamespace setVariable [format ["BO_payday_group_%1",      _jobid], grpNull];
        missionNamespace setVariable [format ["BO_payday_crate_%1",      _jobid], objNull];
        missionNamespace setVariable [format ["BO_payday_looted_%1",     _jobid], false];
        missionNamespace setVariable [format ["BO_payday_looterUID_%1",  _jobid], ""];
        missionNamespace setVariable [format ["BO_payday_reward_%1",     _jobid], _reward];
        missionNamespace setVariable [format ["BO_payday_prepMarker_%1", _jobid], _prepMarker];
        missionNamespace setVariable [format ["BO_payday_destMarker_%1", _jobid], _destMarker];
        missionNamespace setVariable [format ["BO_payday_convoyMarker_%1", _jobid], ""];
        true
    },
    {
        // Fail: convoy reaches destination safely. ONLY checkable
        // after deployment -- pre-deployment the convoy doesn't
        // exist, can't have reached anywhere.
        params ["_jobid"];
        private _deployed = missionNamespace getVariable [format ["BO_payday_deployed_%1", _jobid], false];
        if (!_deployed) exitWith { false };

        private _lead    = missionNamespace getVariable [format ["BO_payday_lead_%1",    _jobid], objNull];
        private _destPos = missionNamespace getVariable [format ["BO_payday_destPos_%1", _jobid], [0,0,0]];
        if (isNull _lead) exitWith { false };
        (alive _lead) && { (_lead distance2D _destPos) < 100 }
    },
    {
        params ["_jobid"];

        private _deployed = missionNamespace getVariable [format ["BO_payday_deployed_%1", _jobid], false];

        // ---- Phase 1 tick: prep countdown + spawn trigger ----
        if (!_deployed) then {
            private _spawnTime = missionNamespace getVariable [format ["BO_payday_spawnTime_%1", _jobid], 0];
            private _remaining = _spawnTime - serverTime;

            // Update the prep marker countdown text.
            private _prepMarker = missionNamespace getVariable [format ["BO_payday_prepMarker_%1", _jobid], ""];
            private _originName = missionNamespace getVariable [format ["BO_payday_originName_%1", _jobid], ""];
            if (_prepMarker != "") then {
                if (_remaining > 0) then {
                    private _mm = floor (_remaining / 60);
                    private _ss = floor (_remaining mod 60);
                    private _mmStr = if (_mm < 10) then { format ["0%1", _mm] } else { str _mm };
                    private _ssStr = if (_ss < 10) then { format ["0%1", _ss] } else { str _ss };
                    _prepMarker setMarkerText format ["NATO Payroll Convoy -- departing %1 in %2:%3",
                        _originName, _mmStr, _ssStr];
                };
            };

            // At T-0: spawn the convoy, flip the deployed flag, swap
            // the prep marker for the active tracker marker.
            if (_remaining <= 0) then {
                private _spawnPos     = missionNamespace getVariable [format ["BO_payday_spawnPos_%1",   _jobid], [0,0,0]];
                private _heading      = missionNamespace getVariable [format ["BO_payday_heading_%1",    _jobid], 0];
                private _leadClass    = missionNamespace getVariable [format ["BO_payday_leadClass_%1",  _jobid], OT_NATO_Vehicle_Transport_Light];
                private _truckClass   = missionNamespace getVariable [format ["BO_payday_truckClass_%1", _jobid], OT_NATO_Vehicle_Transport_Light];
                private _tailClass    = missionNamespace getVariable [format ["BO_payday_tailClass_%1",  _jobid], OT_NATO_Vehicle_Transport_Light];
                private _destPos      = missionNamespace getVariable [format ["BO_payday_destPos_%1",    _jobid], [0,0,0]];

                // Spawn the three vehicles spaced 12m apart along the
                // road, all facing the destination.
                private _spacing = 12;
                private _backOffset1 = [_spawnPos select 0, _spawnPos select 1, 0] getPos [_spacing,     _heading + 180];
                private _backOffset2 = [_spawnPos select 0, _spawnPos select 1, 0] getPos [_spacing * 2, _heading + 180];

                private _lead = _leadClass createVehicle _spawnPos;
                _lead setPosATL _spawnPos;
                _lead setDir _heading;
                _lead setVariable ["BO_exempt", true, true];
                createVehicleCrew _lead;
                { _x setVariable ["BO_exempt", true, true] } forEach (crew _lead);

                private _truck = _truckClass createVehicle _backOffset1;
                _truck setPosATL _backOffset1;
                _truck setDir _heading;
                _truck setVariable ["BO_exempt", true, true];
                createVehicleCrew _truck;
                { _x setVariable ["BO_exempt", true, true] } forEach (crew _truck);

                private _tail = _tailClass createVehicle _backOffset2;
                _tail setPosATL _backOffset2;
                _tail setDir _heading;
                _tail setVariable ["BO_exempt", true, true];
                createVehicleCrew _tail;
                { _x setVariable ["BO_exempt", true, true] } forEach (crew _tail);

                // Merge all three crews into the lead's group so the
                // convoy follows a single waypoint chain.
                private _group = group ((crew _lead) param [0, objNull]);
                if (!isNull _group) then {
                    _group setBehaviour "SAFE";
                    _group setCombatMode "YELLOW";
                    _group setSpeedMode "NORMAL";
                    _group setVariable ["VCM_TOUGHSQUAD", true, true];

                    {
                        private _crewGrp = group _x;
                        if (!isNull _crewGrp && _crewGrp != _group) then {
                            (units _crewGrp) joinSilent _group;
                        };
                    } forEach ((crew _truck) + (crew _tail));

                    private _wp = _group addWaypoint [_destPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointBehaviour "SAFE";
                    _wp setWaypointCombatMode "YELLOW";
                    _wp setWaypointSpeed "NORMAL";
                    _wp setWaypointFormation "COLUMN";
                };

                // Cash crate attached to the truck. Detaches on
                // destruction; players walk up and ACE-Take.
                private _crate = "B_supplyCrate_F" createVehicle [0, 0, 0];
                _crate attachTo [_truck, [0, -1.5, 0]];
                _crate setVariable ["BO_payday_crate", _jobid, true];
                _crate setVariable ["BO_exempt", true, true];
                _crate addItemCargoGlobal ["FirstAidKit", 4];

                missionNamespace setVariable [format ["BO_payday_lead_%1",  _jobid], _lead];
                missionNamespace setVariable [format ["BO_payday_truck_%1", _jobid], _truck];
                missionNamespace setVariable [format ["BO_payday_tail_%1",  _jobid], _tail];
                missionNamespace setVariable [format ["BO_payday_group_%1", _jobid], _group];
                missionNamespace setVariable [format ["BO_payday_crate_%1", _jobid], _crate];

                // Swap prep marker for the live tracker.
                private _prepMarker = missionNamespace getVariable [format ["BO_payday_prepMarker_%1", _jobid], ""];
                if (_prepMarker != "") then { deleteMarker _prepMarker };
                missionNamespace setVariable [format ["BO_payday_prepMarker_%1", _jobid], ""];

                private _convoyMarker = createMarker [format ["BO_payday_convoy_%1", _jobid], getPos _truck];
                _convoyMarker setMarkerType "mil_destroy";
                _convoyMarker setMarkerColor "ColorRed";
                _convoyMarker setMarkerText "Payday Convoy (cash truck)";
                _convoyMarker setMarkerSize [1.2, 1.2];
                missionNamespace setVariable [format ["BO_payday_convoyMarker_%1", _jobid], _convoyMarker];

                missionNamespace setVariable [format ["BO_payday_deployed_%1", _jobid], true];

                // Notify ONLY the player who accepted the job. The OT
                // job runner (CBA_fnc_addPerFrameHandler inside
                // fn_startJob) runs locally on the accepting client,
                // so the success-poll block we're inside is already
                // scoped to that one player -- a plain `call` to the
                // OT notification fn fires on that player's screen
                // only, no broadcast to other clients.
                "NATO payroll convoy has departed -- track it on the map." call OT_fnc_notifyMinor;
            };

            // No loot to check during prep.
            false
        } else {
            // ---- Phase 2 tick: update tracker + check loot ----
            private _truck = missionNamespace getVariable [format ["BO_payday_truck_%1", _jobid], objNull];
            private _convoyMarker = missionNamespace getVariable [format ["BO_payday_convoyMarker_%1", _jobid], ""];

            // Tracker follows the truck while alive. After truck is
            // destroyed, marker stays at last position (don't move it)
            // so players can find the wreck + crate.
            if (_convoyMarker != "" && !isNull _truck && alive _truck) then {
                _convoyMarker setMarkerPos (getPos _truck);
            };

            // Loot check.
            private _looted = missionNamespace getVariable [format ["BO_payday_looted_%1", _jobid], false];
            if (_looted) exitWith { true };

            private _crate = missionNamespace getVariable [format ["BO_payday_crate_%1", _jobid], objNull];
            if (isNull _crate) exitWith { false };

            // First on-foot player within 4m claims the loot.
            private _looter = objNull;
            {
                if (alive _x && isNull (objectParent _x)) then {
                    if ((_x distance _crate) < 4) exitWith { _looter = _x };
                };
            } forEach allPlayers;

            if (isNull _looter) exitWith { false };

            private _reward    = missionNamespace getVariable [format ["BO_payday_reward_%1", _jobid], 0];
            private _looterUID = getPlayerUID _looter;

            missionNamespace setVariable [format ["BO_payday_looted_%1",    _jobid], true];
            missionNamespace setVariable [format ["BO_payday_looterUID_%1", _jobid], _looterUID];

            if (_reward > 0 && _looterUID isNotEqualTo "") then {
                [_looterUID, _reward, format ["Payday Convoy loot job=%1", _jobid]] remoteExec ["BO_fnc_bankAdjust", 2, false];
                format ["Cash crate looted -- $%1 deposited to your bank.", _reward] remoteExec ["OT_fnc_notifyGood", _looter, false];
            };

            true
        };
    },
    {
        params ["_jobid", "", "", "", "", "", "", "", "", "", "", "_reward", "", "_wassuccess"];

        private _lead         = missionNamespace getVariable [format ["BO_payday_lead_%1",         _jobid], objNull];
        private _truck        = missionNamespace getVariable [format ["BO_payday_truck_%1",        _jobid], objNull];
        private _tail         = missionNamespace getVariable [format ["BO_payday_tail_%1",         _jobid], objNull];
        private _group        = missionNamespace getVariable [format ["BO_payday_group_%1",        _jobid], grpNull];
        private _crate        = missionNamespace getVariable [format ["BO_payday_crate_%1",        _jobid], objNull];
        private _prepMarker   = missionNamespace getVariable [format ["BO_payday_prepMarker_%1",   _jobid], ""];
        private _destMarker   = missionNamespace getVariable [format ["BO_payday_destMarker_%1",   _jobid], ""];
        private _convoyMarker = missionNamespace getVariable [format ["BO_payday_convoyMarker_%1", _jobid], ""];

        if (!isNull _group) then { { _x setVariable ["BO_exempt", false, true] } forEach (units _group) };

        // Wrecks + bodies + crate stay 1hr for looting.
        [[_lead, _truck, _tail, _group, _crate]] call BO_fnc_logMissionDebris;

        // Delete every map marker the mission created. deleteMarker on
        // an empty string is a no-op so the missing-marker case is
        // safe (e.g. mission ended during prep before convoy spawn).
        { if (_x != "") then { deleteMarker _x } } forEach [_prepMarker, _destMarker, _convoyMarker];

        // Clear all mission-namespace keys.
        {
            missionNamespace setVariable [format [_x, _jobid], nil];
        } forEach [
            "BO_payday_spawnTime_%1", "BO_payday_deployed_%1",
            "BO_payday_spawnPos_%1", "BO_payday_heading_%1",
            "BO_payday_leadClass_%1", "BO_payday_truckClass_%1", "BO_payday_tailClass_%1",
            "BO_payday_originName_%1", "BO_payday_destPos_%1",
            "BO_payday_lead_%1", "BO_payday_truck_%1", "BO_payday_tail_%1",
            "BO_payday_group_%1", "BO_payday_crate_%1",
            "BO_payday_looted_%1", "BO_payday_looterUID_%1", "BO_payday_reward_%1",
            "BO_payday_prepMarker_%1", "BO_payday_destMarker_%1", "BO_payday_convoyMarker_%1"
        ];

        // No OT_fnc_money: payout happened via bankAdjust on the
        // looting tick.
    },
    _params
]
