//Let's find some NATO to shoot

private _done = player getVariable ["OT_tutesDone", []];
_done pushBackUnique "NATO";
player setVariable ["OT_tutesDone", _done, true];

private _targets = [];
private _destination = [];
private _thistown = (getPosATL player) call OT_fnc_nearestTown;

//Is there some already spawned within spawn distance?
{
    if (side _x isEqualTo blufor) then {
        _targets pushBack _x;
    };
} forEach (player nearEntities ["CAManBase", OT_spawnDistance]);

//No? well where is a town that they control
if (_targets isEqualTo []) exitWith {
    private _towns = [OT_townData, [], { (_x select 0) distance player }, "ASCEND"] call BIS_fnc_sortBy;
    private _town = "";
    private _done = false;
    {
        _x params ["_pos", "_t"];
        if !((_t in (server getVariable ["NATOabandoned", []])) || (_t == _thistown)) exitWith {
            _destination = _pos;
            _town = _t;
            _done = true;
        };
        if (_done) exitWith {};
    } forEach (_towns);

    if (_destination isNotEqualTo []) then {
        //give waypoint
        [player, _destination, _town] call OT_fnc_givePlayerWaypoint;

        format [
            "There doesnt seem to be any NATO nearby. Head to %1, you should be able to find some NATO there. It's marked on your map",
            _town
        ] call OT_fnc_notifyMinor;

        [
            {
                player distance _this < 200;
            },
            {
                //If the player fast travelled, give time to spawn
                [
                    {
                        //loop and hope we find a target
                        [] call (OT_tutorialMissions select 0);
                    },
                    0,
                    10
                ] call CBA_fnc_waitAndExecute;
            },
            _destination
        ] call CBA_fnc_waitUntilAndExecute;
    } else {
        //I guess resistance controls the entire map, gg
    };
};

"There is a group of NATO nearby, their position has been marked on your map. Let's show them we've had enough." call OT_fnc_notifyMinor;
//pick the closest group and reveal

private _sorted = [_targets, [], { _x distance player }, "ASCEND"] call BIS_fnc_sortBy;
private _group = group (_sorted select 0);
player reveal [leader _group, 4];

//give waypoint
private _dest = expectedDestination leader _group;
private _destpos = _dest select 0;
private _wp = [player, _destpos, "NATO"] call OT_fnc_givePlayerWaypoint;

private _total = count units _group;

// Session-scoped sentinel; New Game or a different tute loop starting will flip this and any in-flight loop will exit.
OT_tute_activeLoop = "NATO";

private _loopCode = {
    params ["_loopCode", "_wp", "_reached", "_group", "_total", "_done", "_lastNum"];

    // Abort if a different tute (or none) is now active — prevents zombie loops after disconnect/New Game
    if !((missionNamespace getVariable ["OT_tute_activeLoop", ""]) isEqualTo "NATO") exitWith {};

    if (!isNil "_wp") then {
        //update waypoint
        OT_missionMarker = getPosATLVisual leader _group;
        _wp setWaypointPosition [OT_missionMarker, 0];
    };
    if (!_reached) then {
        _reached = player distance (leader _group) < 30;
    } else {
        private _num = _total - ({ alive _x } count units _group);
        _done = _num >= _total;
        // Only update the hint when the kill count actually changes (avoid spamming hintSilent every 0.5s)
        if (_num != _lastNum) then {
            hintSilent format ["Kills: %1/%2", _num, _total];
            _lastNum = _num;
        };
    };

    if !(_done) then {
        [
            _loopCode,
            [_loopCode, _wp, _reached, _group, _total, false, _lastNum],
            0.5
        ] call CBA_fnc_waitAndExecute;
    } else {
        [player, 250] call OT_fnc_rewardMoney;
        call OT_fnc_clearPlayerWaypoint;
        // Clear sentinel so a future tute can claim it
        OT_tute_activeLoop = "";
    };
};

[_loopCode, _wp, false, _group, _total, false, -1] call _loopCode;
