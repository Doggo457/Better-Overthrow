params ["_id", "_job", "_repeat", "_expires"];
_job params ["_info", "_markerPos", "_setup", "_fail", "_success", "_end", "_jobparams"];
if !(_jobparams call _setup) exitWith {
    private _active = spawner getVariable ["OT_activeJobs", []];
    private _idx = -1;
    {
        _x params ["_cid"];
        if (_cid == _id) exitWith { _idx = _forEachIndex };
    } forEach _active;
    if (_idx > -1) then {
        _active deleteAt _idx;
        spawner setVariable ["OT_activeJobs", _active, true];
    };

    _active = spawner getVariable ["OT_activeJobIds", []];
    _active deleteAt (_active find _id);
    spawner setVariable ["OT_activeJobIds", _active, true];
};

[
    {
        params ["_id", "_job", "_repeat", "_info", "_markerPos", "_setup", "_fail", "_success", "_end", "_jobparams", "_expires"];

        private _done = false;
        spawner setVariable [format ["OT_jobRemain%1", _id], _expires * 60, true];

        if (_expires < 1) then {
            spawner setVariable [format ["OT_jobNoExpire%1", _id], true, true];
        };
        [
            {
                (_this select 0) params ["_done", "_id", "_job", "_repeat", "", "", "", "_fail", "_success", "_end", "_jobparams", "_expires", "_lastdate"];
                private _handle = _this select 1;
                private _remains = spawner getVariable [format ["OT_jobRemain%1", _id], 0];
                if (!_done) then {
                    private _date = call OT_fnc_datestamp;
                    _remains = _remains - (_date - _lastdate);
                    (_this select 0) set [12, _date]; //updates _lastdate
                    if (_expires < 1) then { _remains = 1 };
                    private _wassuccess = false;
                    if (call {
                        if (_remains <= 0) exitWith {
                            _wassuccess = false;
                            true;
                        };
                        if (_jobparams call _success) exitWith {
                            _wassuccess = true;
                            true;
                        };
                        if (_jobparams call _fail) exitWith {
                            _wassuccess = false;
                            true;
                        };
                        false;
                    }) then {
                        _jobparams pushBack _wassuccess;
                        _jobparams call _end;
                        private _active = spawner getVariable ["OT_activeJobs", []];
                        private _idx = -1;
                        {
                            _x params ["_cid"];
                            if (_cid == _id) exitWith { _idx = _forEachIndex };
                        } forEach _active;
                        if (_idx > -1) then {
                            _active deleteAt _idx;
                            spawner setVariable ["OT_activeJobs", _active, true];
                        };

                        _active = spawner getVariable ["OT_activeJobIds", []];
                        _active deleteAt (_active find _id);
                        spawner setVariable ["OT_activeJobIds", _active, true];

                        // Notify ONLY the player whose machine is
                        // running this PFH (the job's accepter).
                        // CBA_fnc_addPerFrameHandler is local-effect,
                        // so this lambda only runs on the accepter's
                        // client; a direct `call` to the OT notify
                        // function fires on that one screen only.
                        // Previous `remoteExec [..., 0, false]` was
                        // broadcasting every player's job result to
                        // every other player.
                        if (_wassuccess) then {
                            format ["Job completed: %1", (_job select 0) select 0] call OT_fnc_notifyGood;
                        } else {
                            if (_remains > 0) then {
                                format ["Job failed: %1", (_job select 0) select 0] call OT_fnc_notifyBad;
                            } else {
                                format ["Job expired: %1", (_job select 0) select 0] call OT_fnc_notifyBad;
                            };
                        };

                        if (_remains > 0) then {
                            if (_repeat < 1) then {
                                private _completed = server getVariable ["OT_completedJobIds", []];
                                _completed pushBack _id;
                                // MP sync: without `true` the completed-job list never reaches other clients/JIP and the FOB dialog re-offers finished jobs.
                                server setVariable ["OT_completedJobIds", _completed, true];
                            };
                        };

                        [_handle] call CBA_fnc_removePerFrameHandler;
                    };
                    spawner setVariable [format ["OT_jobRemain%1", _id], _remains, true];
                };
            },
            2,
            [_done, _id, _job, _repeat, _info, _markerPos, _setup, _fail, _success, _end, _jobparams, _expires, call OT_fnc_datestamp]
        ] call CBA_fnc_addPerFrameHandler;
    },
    [_id, _job, _repeat, _info, _markerPos, _setup, _fail, _success, _end, _jobparams, _expires],
    5
] call CBA_fnc_waitAndExecute;
