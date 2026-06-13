params ["", "_jobparams"];
_jobparams params ["_base", "_markerPos"];

// BO: per-base contribution tracking. Maps participant UID -> number
// of recon ticks they were present for. Reward splits proportionally
// among contributors at completion. Stored on the spawner namespace
// keyed by base so it survives the lifetime of the active job.
private _contribKey = format ["BO_reconContrib_%1", _base];
spawner setVariable [_contribKey, createHashMap, false];

// Base reward scales with garrison density at the moment of success.
// $250 / soldier + $1000 / vehicle is paid into the shared pool and
// split among contributors. Floor of $1500 total guarantees the
// mission is worth running even on a sparse base.
private _params = [_base, 0];
private _effect = "<t size='0.9'>Reward: scales with garrison size, split between players who participated.</t>";

private _description = format ["Get information on the NATO forces and vehicles garrisoned at %1. Bring a Rangefinder or Binoculars and stay outside the spawn radius -- NATO doesn't like sightseers. The reward is split between players who were within recon range while the count progressed.<br/><br/>%2", _base, _effect];
private _title = format ["Recon of %1", _base];

[
    [_title, _description],
    _markerPos,
    {
        //No setup required for this mission
        true;
    },
    {
        //Fail check...
        false;
    },
    {
        //Success Check
        params ["_base", "_oldcount"];

        private _loc = server getVariable _base;

        // Anyone alive within spawn distance counts as a participant
        // for THIS tick. We tally per-tick because recon is a group
        // activity; sitting outside the perimeter watching counts.
        private _participants = [];
        {
            if (isPlayer _x && alive _x) then {
                _participants pushBack _x;
            };
        } forEach (_loc nearEntities ["Man", OT_spawnDistance]);

        if (_participants isEqualTo []) exitWith { false };

        private _spawnid = spawner getVariable [format ["spawnid%1", _base], ""];
        if (_spawnid isEqualTo "") exitWith { false }; //Base has not been spawned yet
        private _groups = spawner getVariable [_spawnid, []];
        if (_groups isEqualTo []) exitWith { false }; //Base is empty/not spawned atm

        private _count = 0;
        private _missedOne = false;
        {
            private _group = _x;
            if ((typeName _group isEqualTo "GROUP") && !isNull (leader _group)) then {
                if (isNull objectParent leader _group) then {
                    if ((independent knowsAbout (leader _x)) <= 1.2) then {
                        _missedOne = true;
                    } else {
                        _count = _count + (count units _group);
                    };
                };
            };
        } forEach (_groups);

        // BO: record each present player's contribution. Only count
        // ticks where the recon made measurable progress (count went
        // up) so AFK presence doesn't inflate the split.
        if (_oldcount < _count) then {
            private _contribKey = format ["BO_reconContrib_%1", _base];
            private _contrib = spawner getVariable [_contribKey, createHashMap];
            {
                private _uid = getPlayerUID _x;
                if (_uid isNotEqualTo "") then {
                    _contrib set [_uid, ((_contrib getOrDefault [_uid, 0]) + 1)];
                };
            } forEach _participants;
            spawner setVariable [_contribKey, _contrib, false];
        };

        _this set [1, _count];
        !_missedOne;
    },
    {
        params ["_base", "_lastKnownCount", "_wassuccess"];

        // No early-end path -- the feature was removed. Job ends only
        // via natural success or expire/fail; both flow through here.
        if (!_wassuccess) exitWith {};

        // Recon flag for persistent garrison feature -- the player
        // saw it through to full completion.
        server setVariable [format ["BO_reconned_%1", _base], true, true];

        // Compute reward scale based on what was actually at the base.
        private _soldierCount = server getVariable [format ["garrison%1", _base], 0];
        private _vehs = (server getVariable [format ["vehgarrison%1", _base], []])
                      + (server getVariable [format ["airgarrison%1", _base], []]);
        private _vehCount = 0;
        { _vehCount = _vehCount + (_x param [1, 0]) } forEach _vehs;

        private _totalReward = (_soldierCount * 250) + (_vehCount * 1000);
        if (_totalReward < 1500) then { _totalReward = 1500 };

        // Split among contributors proportionally to their tick count.
        private _contribKey = format ["BO_reconContrib_%1", _base];
        private _contrib = spawner getVariable [_contribKey, createHashMap];

        // Fallback: if for some reason no contributors were recorded
        // (mission finished in a single tick, weird timing), pay
        // anyone presently near the base.
        if ((count _contrib) isEqualTo 0) then {
            private _loc = server getVariable _base;
            {
                if (isPlayer _x && alive _x) then {
                    _contrib set [getPlayerUID _x, 1];
                };
            } forEach (_loc nearEntities ["Man", OT_spawnDistance]);
        };

        private _totalTicks = 0;
        { _totalTicks = _totalTicks + _y } forEach _contrib;

        private _payouts = "";
        if (_totalTicks > 0) then {
            {
                private _uid = _x;
                private _ticks = _y;
                private _share = floor (_totalReward * (_ticks / _totalTicks));
                if (_share <= 0) then { _share = 1 };

                // Find the player object by UID to push the reward.
                private _player = objNull;
                {
                    if (getPlayerUID _x isEqualTo _uid) exitWith { _player = _x };
                } forEach allPlayers;

                if (!isNull _player) then {
                    [_share, "Recon"] remoteExec ["OT_fnc_money", _player, false];
                    _payouts = _payouts + format ["<br/>%1: $%2", name _player, _share];
                };
            } forEach _contrib;
        };
        spawner setVariable [_contribKey, nil, false];

        // Broadcast a single notification to everyone, with the
        // recon report and the payout table.
        private _report = format ["<t size='0.9'>Recon report (%1)</t><br/>", _base];
        _report = _report + format ["%1 x Soldiers<br/>", _soldierCount];
        {
            _x params ["_cls", "_num"];
            _report = _report + format ["%1 x %2<br/>", _num, _cls call OT_fnc_vehicleGetName];
        } forEach (_vehs call BIS_fnc_consolidateArray);
        _report = _report + format ["<br/><t size='0.8'>Total reward $%1 split:</t>%2",
            [_totalReward, 1, 0, true] call CBA_fnc_formatNumber, _payouts];

        // Job result -- notify only the player whose machine is
        // running this PFH (the recon job's accepter), not every
        // connected client. Per-player bank payouts are dispatched
        // separately above so contributors still get their money;
        // only the visual report is scoped to the accepter.
        _report call OT_fnc_notifyBig;
    },
    _params
];
