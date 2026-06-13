/*
 * BO mission: Distribute Leaflets
 *
 * Player walks (or drives) through 3 distinct NATO-controlled
 * town centres carrying resistance leaflets. No spawned units.
 * Pure traversal mission -- low risk, low reward.
 *
 * Reward: $1500 + 5 standing in each visited town.
 *
 * No ACE dependency. Leaflets are represented by a FirstAidKit
 * placeholder added to player inventory at acceptance (visual
 * flavour only; the "drop" is detected by proximity).
 */

params ["_jobid", "_jobparams"];

if (isNil "OT_townData" || { OT_townData isEqualTo [] }) exitWith { [] };

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
private _inRange = _natoTowns select { ((_x select 0) distance2D player) <= 3000 };
if (count _inRange < 3) exitWith { [] };

private _sorted = [_inRange, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _picked = _sorted select [0, 3];
private _townNames = _picked apply { _x select 1 };
private _markerPos = (_picked select 0) select 0;

private _reward = 1500;
private _title = "Distribute Leaflets";
private _description = format [
    "Drive (or walk) through the centre of 3 NATO-held towns -- %1, %2, %3 -- carrying resistance leaflets. Leaflets are added to your inventory on acceptance. Get within 80m of each town centre; the leaflets will be 'dropped' automatically. No combat required if you stay quiet.<br/><br/>Reward: $%4 + standing in each town.",
    _townNames select 0,
    _townNames select 1,
    _townNames select 2,
    _reward
];

private _params = [_jobid, _picked, _townNames, _reward];

[
    [_title, _description],
    _markerPos,
    {
        params ["_jobid", "_picked", "_townNames"];

        // No spawned units. Just give each living player a placeholder leaflet item.
        { if (alive _x) then { _x addItem "FirstAidKit" } } forEach allPlayers;

        missionNamespace setVariable [format ["BO_leaflets_remaining_%1", _jobid], +_townNames];
        missionNamespace setVariable [format ["BO_leaflets_visited_%1",   _jobid], []];
        missionNamespace setVariable [format ["BO_leaflets_picked_%1",    _jobid], _picked];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _remaining = missionNamespace getVariable [format ["BO_leaflets_remaining_%1", _jobid], []];
        private _visited   = missionNamespace getVariable [format ["BO_leaflets_visited_%1",   _jobid], []];
        private _picked    = missionNamespace getVariable [format ["BO_leaflets_picked_%1",    _jobid], []];
        if (_remaining isEqualTo []) exitWith { true };

        private _newRemaining = _remaining select {
            private _townName = _x;
            private _townEntry = _picked select { (_x select 1) isEqualTo _townName };
            if (_townEntry isEqualTo []) exitWith { true };
            private _townPos = (_townEntry select 0) select 0;
            private _close = allPlayers findIf { alive _x && {(_x distance2D _townPos) < 80} };
            if (_close >= 0) then {
                _visited pushBack _townName;
                private _msg = format ["Leaflets dropped in %1.", _townName];
                _msg call OT_fnc_notifyGood;
                false
            } else {
                true
            };
        };
        missionNamespace setVariable [format ["BO_leaflets_remaining_%1", _jobid], _newRemaining];
        missionNamespace setVariable [format ["BO_leaflets_visited_%1",   _jobid], _visited];
        _newRemaining isEqualTo []
    },
    {
        params ["_jobid", "", "_townNames", "_reward", "_wassuccess"];

        missionNamespace setVariable [format ["BO_leaflets_remaining_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_leaflets_visited_%1",   _jobid], nil];
        missionNamespace setVariable [format ["BO_leaflets_picked_%1",    _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Distributed Leaflets"] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                { [_x, 5, format ["Leafletted %1", _x]] call OT_fnc_support } forEach _townNames;
            };
        };
    },
    _params
]
