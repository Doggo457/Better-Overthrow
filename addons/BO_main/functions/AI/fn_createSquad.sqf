private _units = groupSelectedUnits player;
if (count _units < 2) exitWith { "You must select at least 2 recruits" call OT_fnc_notifyMinor };
private _group = createGroup independent;
private _cc = player getVariable ["OT_squadcount", 1];
{
    if (_x != player) then {
        _x setVariable ["NOAI", false, false];
        [_x] joinSilent _group;
    };
} forEach (_units);
_group setGroupIdGlobal [format ["S-%1", _cc]];
_cc = _cc + 1;
player hcSetGroup [_group, groupId _group, "teamgreen"];

player setVariable ["OT_squadcount", _cc, true];

// MP race: route through server-only adjuster instead of client RMW of server "squads"
[[getPlayerUID player, "CUSTOM", _group, []]] remoteExec ["BO_fnc_addSquad", 2, false];

// MP race: graduate recruits via server-only pruner so the "recruits" RMW happens server-side
[_units] remoteExec ["BO_fnc_removeRecruitsByUnits", 2, false];

"Squad created, use ctrl + space to command" call OT_fnc_notifyMinor;
