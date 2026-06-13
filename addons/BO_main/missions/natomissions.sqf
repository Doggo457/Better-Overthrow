params ["", "_jobparams"];
_jobparams params ["_missiondef"];

private _params = [_missiondef];
_missiondef params ["", "_missiontype", "_p1", "_p2", "_hour"];

//Build a mission description and title
private _description = "";
private _title = "";

if (_missiontype == "CONVOY") then {
    _description = format ["We have received intel that NATO will be running a convoy from %1 to %2 at approximately %3:00 today.", _p1 select 1, _p2 select 1, _hour];
    _title = format ["NATO Convoy from %1 to %2", _p1 select 1, _p2 select 1];
    // Job-flavor intel briefing -- notify only the player whose
    // machine is running this script (the job's accepter / offer
    // recipient), not every connected client.
    _description call OT_fnc_notifyMinor;
};

private _markerPos = _p2 select 0;

//The data below is what is returned to the gun dealer/faction rep, _markerPos is where to put the mission marker, the code in {} brackets is the actual mission code, only run if the player accepts
[
    [_title, _description],
    _markerPos,
    {
        //No setup required
        true;
    },
    {
        //Fail check...
        //something is alive and made it to destination
        params ["_missiondef"];
        _missiondef params ["_id", "", "", "_p2"];
        private _group = spawner getVariable [format ["spawn%1", _id], nil];
        private _topos = _p2 select 0;
        private _failed = false;
        if (!isNil "_group" && (units _group) isNotEqualTo []) then {
            private _pos = getPos (leader _group);
            if ((_pos distance2D _topos) < 50) exitWith { _failed = true };
        };

        _failed;
    },
    {
        //Succeed check...
        //everyone is dead
        params ["_missiondef"];
        _missiondef params ["_id"];
        private _group = spawner getVariable [format ["spawn%1", _id], nil];
        (units _group) isEqualTo [];
    },
    {
        //we dont need to do anything
    },
    _params
];
