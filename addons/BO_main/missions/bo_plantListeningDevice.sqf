/*
 * BO mission: Plant Listening Device
 *
 * Player enters a NATO-controlled town, finds a real town
 * building, and plants a listening device via addAction on
 * the building. On planting:
 *   - mission completes immediately
 *   - for the next ~36 real-time minutes (24 mission hours at
 *     OT default time accel), any NATO unit within 800m of the
 *     device gets pinged with a transient map marker
 *
 * Light interior NATO presence (2 stationary guards). Player is
 * not required to clear them -- it's a sneak job.
 *
 * Reward: $3000 + 10 standing in the host town.
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

private _houses = (nearestObjects [_townPos, ["House"], 200]) select { !(_x call OT_fnc_hasOwner) };
private _validHouses = [];
{
    private _h = _x;
    private _bboxR = boundingBoxReal _h;
    private _bldH = (_bboxR select 1 select 2) - (_bboxR select 0 select 2);
    if (_bldH < 3) then { continue };
    private _hGroundZ = (getPosATL _h) select 2;
    private _bps = (_h buildingPos -1) select {
        !(_x isEqualTo [0,0,0])
            && ((_x select 2) - _hGroundZ) < 1.8
            && !(surfaceIsWater [_x select 0, _x select 1])
    };
    if (count _bps >= 2) then { _validHouses pushBack _h };
} forEach _houses;
if (_validHouses isEqualTo []) exitWith { [] };

private _house = selectRandom _validHouses;
private _housePos = getPosATL _house;

private _reward = 3000;
private _title = format ["Plant Listening Device in %1", _townName];
private _description = format [
    "Sneak into a marked building in %1 and plant a listening device. Once it's live, NATO unit positions within 800m get pinged on your map for ~24 mission hours. Try to avoid the interior guards rather than start a firefight.<br/><br/>Reward: $%2 + town standing.",
    _townName, _reward
];

private _params = [_jobid, _house, _housePos, _townName, _reward];

[
    [_title, _description],
    _housePos,
    {
        params ["_jobid", "_house", "_housePos"];

        // 2 stationary interior guards. No alarm reinforcements --
        // this is a sneak job.
        private _group = createGroup [blufor, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        private _pool = OT_NATO_Units_LevelOne;
        if (_pool isEqualTo []) then { _pool = [OT_NATO_Unit_TeamLeader] };

        private _hGroundZ = (getPosATL _house) select 2;
        private _bps = (_house buildingPos -1) select {
            !(_x isEqualTo [0,0,0])
                && ((_x select 2) - _hGroundZ) < 1.8
                && !(surfaceIsWater [_x select 0, _x select 1])
        };
        _bps = _bps call BIS_fnc_arrayShuffle;

        for "_i" from 1 to 2 do {
            private _bp = if (_bps isNotEqualTo []) then { _bps deleteAt 0 } else { _housePos getPos [3, random 360] };
            private _u = _group createUnit [selectRandom _pool, _bp, [], 0, "NONE"];
            _u setPosATL [_bp select 0, _bp select 1, (_bp select 2) + 0.2];
            _u setVariable ["BO_exempt", true, true];
            _u setUnitPos "MIDDLE";
            doStop _u;
            _u disableAI "PATH";
            [_u, "BO_Bug"] call OT_fnc_initMilitary;
        };

        // Plant action attached to the building itself.
        private _act = _house addAction [
            "<t color='#80c0ff'>Plant Listening Device</t>",
            {
                params ["_t", "_caller", "_jobid"];
                private _devPos = _caller modelToWorld [0, 1, 0];
                private _dev = createVehicle ["Land_PortableLongRangeRadio_F", _devPos, [], 0, "NONE"];
                _dev setPosATL [_devPos select 0, _devPos select 1, (_devPos select 2)];
                _dev setVariable ["BO_exempt", true, true];
                missionNamespace setVariable [format ["BO_intel_device_%1", _jobid], _dev, true];
                missionNamespace setVariable [format ["BO_intel_planted_%1", _jobid], true, true];
                // ~36 real minutes (rough 24 mission hours at OT default accel).
                missionNamespace setVariable [format ["BO_intel_revealUntil_%1", _jobid], serverTime + 2160, true];
                "Listening device planted -- NATO movement pinging on your map." call OT_fnc_notifyGood;
            },
            _jobid,
            1.5,
            true,
            true,
            "",
            "_this distance _target < 4 && (vehicle _this isEqualTo _this)"
        ];

        missionNamespace setVariable [format ["BO_intel_targetBuilding_%1", _jobid], _house];
        missionNamespace setVariable [format ["BO_intel_group_%1",          _jobid], _group];
        missionNamespace setVariable [format ["BO_intel_planted_%1",        _jobid], false];
        missionNamespace setVariable [format ["BO_intel_action_%1",         _jobid], _act];
        missionNamespace setVariable [format ["BO_intel_pingMarkers_%1",    _jobid], []];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _planted = missionNamespace getVariable [format ["BO_intel_planted_%1", _jobid], false];
        if (!_planted) exitWith { false };

        // Refresh ping markers while the reveal window is active.
        private _dev = missionNamespace getVariable [format ["BO_intel_device_%1", _jobid], objNull];
        private _until = missionNamespace getVariable [format ["BO_intel_revealUntil_%1", _jobid], 0];
        if (!isNull _dev && {serverTime < _until}) then {
            private _existing = missionNamespace getVariable [format ["BO_intel_pingMarkers_%1", _jobid], []];
            { deleteMarker _x } forEach _existing;
            private _newMarkers = [];
            private _nearNATO = (getPosATL _dev) nearEntities ["Man", 800];
            _nearNATO = _nearNATO select { (side _x) isEqualTo blufor && alive _x };
            {
                private _m = createMarker [format ["BO_intel_ping_%1_%2", _jobid, _forEachIndex], getPosATL _x];
                _m setMarkerType "mil_warning";
                _m setMarkerColor "ColorBLUFOR";
                _m setMarkerText "NATO";
                _newMarkers pushBack _m;
            } forEach _nearNATO;
            missionNamespace setVariable [format ["BO_intel_pingMarkers_%1", _jobid], _newMarkers];
        };

        // Mission completes only AFTER the reveal window elapses so the
        // ping refresh loop above actually gets to run. Returning _planted
        // alone (the original behaviour) ended the mission on the first
        // poll after planting, killing the entire reveal feature.
        _planted && {serverTime >= _until}
    },
    {
        params ["_jobid", "", "", "_townName", "_reward", "_wassuccess"];

        private _group = missionNamespace getVariable [format ["BO_intel_group_%1",          _jobid], grpNull];
        private _dev   = missionNamespace getVariable [format ["BO_intel_device_%1",         _jobid], objNull];
        private _house = missionNamespace getVariable [format ["BO_intel_targetBuilding_%1", _jobid], objNull];
        private _act   = missionNamespace getVariable [format ["BO_intel_action_%1",         _jobid], -1];
        private _pings = missionNamespace getVariable [format ["BO_intel_pingMarkers_%1",    _jobid], []];

        if (!isNull _house && _act >= 0) then { _house removeAction _act };
        { deleteMarker _x } forEach _pings;
        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [[_group, _dev]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_intel_device_%1",         _jobid], nil];
        missionNamespace setVariable [format ["BO_intel_targetBuilding_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_intel_group_%1",          _jobid], nil];
        missionNamespace setVariable [format ["BO_intel_planted_%1",        _jobid], nil];
        missionNamespace setVariable [format ["BO_intel_revealUntil_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_intel_pingMarkers_%1",    _jobid], nil];
        missionNamespace setVariable [format ["BO_intel_action_%1",         _jobid], nil];

        if (_wassuccess) then {
            [_reward, "Planted Listening Device"] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                [_townName, 10, format ["Bugged a building in %1", _townName]] call OT_fnc_support;
            };
        };
    },
    _params
]
