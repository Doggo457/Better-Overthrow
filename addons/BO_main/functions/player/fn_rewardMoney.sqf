params ["_who", "_amount"];
if (isPlayer _who) then {
    [_amount] remoteExec ["OT_fnc_money", _who, false];
} else {
    if ((side _who) isEqualTo independent) then {
        //we spread it amongst everyone
        private _perPlayer = round (_amount / count (allPlayers - (entities "HeadlessClient_F")));
        if (_perPlayer > 0) then {
            {
                [_perPlayer] remoteExec ["OT_fnc_money", _x, false];
            } forEach (allPlayers - (entities "HeadlessClient_F"));
        };
    };
};
