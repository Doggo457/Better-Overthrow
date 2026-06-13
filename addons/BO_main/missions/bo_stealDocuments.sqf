/*
 * BO mission: Steal NATO Documents
 *
 * A NATO command shack holds operational paperwork. Player clears
 * the small garrison, picks up the document item via addAction,
 * and delivers it to any resistance-controlled town (i.e. one in
 * NATOabandoned).
 *
 * Layout: Land_Cargo_HQ_V3_F building spawned 250-450m from a
 * NATO town centre. Document is a Land_File_research_F desk prop
 * inside. 5 guards (2 inside stationary, 3 outside taskDefend).
 *
 * Reward: $4500 + 15 standing in the host town on delivery.
 */

params ["_jobid", "_jobparams"];

if (isNil "OT_townData" || { OT_townData isEqualTo [] }) exitWith { [] };

private _abandoned = server getVariable ["NATOabandoned", []];
private _natoTowns = OT_townData select { !((_x select 1) in _abandoned) };
if (_natoTowns isEqualTo []) exitWith { [] };

private _sorted = [_natoTowns, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (3 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

private _hqPos = [];
for "_attempt" from 1 to 20 do {
    private _c = [_townPos, 250, 450, 20, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_c isEqualType [] && {(count _c) >= 2} && {(_c select 0) > 0}) exitWith {
        _hqPos = [_c select 0, _c select 1, 0];
    };
};
if (_hqPos isEqualTo []) exitWith { [] };

private _reward = 4500;
private _title = format ["Steal Documents near %1", _townName];
private _description = format [
    "NATO has a command shack near %1 holding operational paperwork. Clear the guards, pick up the documents on the desk inside, and bring them back to any resistance-controlled town.<br/><br/>Reward: $%2 + town standing on delivery.",
    _townName, _reward
];

private _params = [_jobid, _hqPos, _townName, _reward];

[
    [_title, _description],
    _hqPos,
    {
        params ["_jobid", "_hqPos"];

        private _baseDir = random 360;
        private _props = [];

        private _hq = createVehicle ["Land_Cargo_HQ_V3_F", _hqPos, [], 0, "CAN_COLLIDE"];
        _hq setDir _baseDir;
        _hq setPosATL _hqPos;
        _hq setVariable ["BO_exempt", true, true];
        _props pushBack _hq;

        private _hGroundZ = (getPosATL _hq) select 2;
        private _bps = (_hq buildingPos -1) select {
            !(_x isEqualTo [0,0,0])
                && ((_x select 2) - _hGroundZ) < 1.8
                && !(surfaceIsWater [_x select 0, _x select 1])
        };
        _bps = _bps call BIS_fnc_arrayShuffle;

        // Documents on a desk inside (or worst-case 1m off the front).
        private _docPos = if (_bps isNotEqualTo []) then { _bps deleteAt 0 } else { _hqPos getPos [1, _baseDir] };
        private _docs = createVehicle ["Land_File_research_F", _docPos, [], 0, "NONE"];
        _docs setPosATL [_docPos select 0, _docPos select 1, (_docPos select 2) + 0.9];
        _docs setVariable ["BO_exempt", true, true];

        private _act = _docs addAction [
            "<t color='#80ffc0'>Grab Documents</t>",
            {
                params ["_t", "_caller", "_jobid"];
                _caller setVariable [format ["BO_docs_carrier_%1", _jobid], true, true];
                missionNamespace setVariable [format ["BO_docs_picked_%1", _jobid], true, true];
                missionNamespace setVariable [format ["BO_docs_pickedAt_%1", _jobid], serverTime, true];
                deleteVehicle _t;
                "Documents acquired -- deliver to any resistance-held town." call OT_fnc_notifyGood;
            },
            _jobid,
            1.5,
            true,
            true,
            "",
            "_this distance _target < 2.5 && (vehicle _this isEqualTo _this)"
        ];

        // 5-person guard: first 2 stationary inside, rest taskDefend the perimeter.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };

        for "_i" from 1 to 5 do {
            private _useInterior = (_i <= 2 && _bps isNotEqualTo []);
            private _spawnPos = if (_useInterior) then { _bps deleteAt 0 } else { _hqPos getPos [13 + (random 8), random 360] };
            private _u = _group createUnit [selectRandom _pool, _spawnPos, [], 0, "NONE"];
            // Interior building positions already encode the correct
            // upper-floor Z relative to terrain; max 0 here would yank
            // them down to ground. Only clamp the exterior fallback.
            private _z = if (_useInterior) then {
                (_spawnPos select 2) + 0.2
            } else {
                ((_spawnPos select 2) + 0.05) max 0
            };
            _u setPosATL [_spawnPos select 0, _spawnPos select 1, _z];
            _u setVariable ["BO_exempt", true, true];
            [_u, "BO_StealDocs"] call OT_fnc_initMilitary;
            if (_useInterior) then {
                _u setUnitPos "MIDDLE";
                doStop _u;
                _u disableAI "PATH";
            };
        };
        [_group, _hqPos, 20] call CBA_fnc_taskDefend;

        missionNamespace setVariable [format ["BO_docs_item_%1",   _jobid], _docs];
        missionNamespace setVariable [format ["BO_docs_group_%1",  _jobid], _group];
        missionNamespace setVariable [format ["BO_docs_props_%1",  _jobid], _props];
        missionNamespace setVariable [format ["BO_docs_picked_%1", _jobid], false];
        missionNamespace setVariable [format ["BO_docs_action_%1", _jobid], _act];
        true
    },
    {
        // Fail path: carrier disconnect deadlock. The document is
        // deleteVehicle'd on pickup so no other player can grab it; if
        // the carrier logs out, the mission is unwinnable. After a 5-min
        // grace window with no live carrier, fail the mission.
        params ["_jobid"];
        private _picked = missionNamespace getVariable [format ["BO_docs_picked_%1", _jobid], false];
        if (!_picked) exitWith { false };
        private _carrier = objNull;
        {
            if (_x getVariable [format ["BO_docs_carrier_%1", _jobid], false] && {alive _x}) exitWith { _carrier = _x };
        } forEach allPlayers;
        if (!isNull _carrier) exitWith { false };
        private _pickedAt = missionNamespace getVariable [format ["BO_docs_pickedAt_%1", _jobid], serverTime];
        (serverTime - _pickedAt) > 300
    },
    {
        params ["_jobid"];
        private _picked = missionNamespace getVariable [format ["BO_docs_picked_%1", _jobid], false];
        if (!_picked) exitWith { false };

        // Find a carrier among players.
        private _carrier = objNull;
        {
            if (_x getVariable [format ["BO_docs_carrier_%1", _jobid], false]) exitWith { _carrier = _x };
        } forEach allPlayers;
        if (isNull _carrier) exitWith { false };
        if (!alive _carrier) exitWith { false };

        // Drop-off: within 200m of any resistance-held town centre.
        private _abandoned = server getVariable ["NATOabandoned", []];
        if (isNil "OT_townData") exitWith { false };
        private _resistanceTowns = OT_townData select { (_x select 1) in _abandoned };
        if (_resistanceTowns isEqualTo []) exitWith { false };
        private _atTown = _resistanceTowns findIf { (_carrier distance2D (_x select 0)) < 200 };
        _atTown >= 0
    },
    {
        params ["_jobid", "", "_townName", "_reward", "_wassuccess"];

        private _docs  = missionNamespace getVariable [format ["BO_docs_item_%1",   _jobid], objNull];
        private _group = missionNamespace getVariable [format ["BO_docs_group_%1",  _jobid], grpNull];
        private _props = missionNamespace getVariable [format ["BO_docs_props_%1",  _jobid], []];
        private _act   = missionNamespace getVariable [format ["BO_docs_action_%1", _jobid], -1];

        if (!isNull _docs && _act >= 0) then { _docs removeAction _act };
        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        { _x setVariable [format ["BO_docs_carrier_%1", _jobid], nil, true] } forEach allPlayers;
        [_props + [_docs, _group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_docs_item_%1",   _jobid], nil];
        missionNamespace setVariable [format ["BO_docs_group_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_docs_props_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_docs_picked_%1",   _jobid], nil];
        missionNamespace setVariable [format ["BO_docs_pickedAt_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_docs_action_%1",   _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Stole NATO Documents"] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                [_townName, 15, format ["Stole NATO documents from %1", _townName]] call OT_fnc_support;
            };
        };
    },
    _params
]
