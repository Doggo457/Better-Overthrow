/*
 * BO mission: Gang Leader Bounty
 *
 * A named CRIM gang leader holed up in a town building with 4
 * bodyguards. Player kills the leader. Host town can be any
 * town (not just NATO-held) since gang leaders are not
 * regime-aligned.
 *
 * The leader is OPFOR-side (east) with a distinguishing
 * safari hat + tac vest so he's visually identifiable.
 *
 * Reward: $4000 + 10 standing in the host town.
 */

params ["_jobid", "_jobparams"];

if (isNil "OT_townData" || { OT_townData isEqualTo [] }) exitWith { [] };

private _sorted = [OT_townData, [], { (_x select 0) distance2D player }, "ASCEND"] call BIS_fnc_sortBy;
private _candidates = _sorted select [0, (5 min count _sorted)];
private _town = selectRandom _candidates;
_town params ["_townPos", "_townName"];

private _houses = (nearestObjects [_townPos, ["House"], 250]) select { !(_x call OT_fnc_hasOwner) };
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
    if (count _bps >= 4) then { _validHouses pushBack _h };
} forEach _houses;
if (_validHouses isEqualTo []) exitWith { [] };

private _house = selectRandom _validHouses;
private _housePos = getPosATL _house;

private _gangNames = ["Doc Mancini", "Big Vasili", "Red Janko", "The Wolf", "Silent Petar"];
private _leaderName = selectRandom _gangNames;
private _reward = 4000;

private _title = format ["Bounty: %1", _leaderName];
private _description = format [
    "%1 -- the gang leader running protection rackets out of %2 -- has a bounty on him. He's holed up in a house in town with four bodyguards. Kill him.<br/><br/>Reward: $%3 + town standing.",
    _leaderName, _townName, _reward
];

private _params = [_jobid, _house, _housePos, _townName, _leaderName, _reward];

[
    [_title, _description],
    _housePos,
    {
        params ["_jobid", "_house", "_housePos", "_townName", "_leaderName"];

        private _hGroundZ = (getPosATL _house) select 2;
        private _bps = (_house buildingPos -1) select {
            !(_x isEqualTo [0,0,0])
                && ((_x select 2) - _hGroundZ) < 1.8
                && !(surfaceIsWater [_x select 0, _x select 1])
        };
        _bps = _bps call BIS_fnc_arrayShuffle;

        private _group = createGroup [east, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        _group setBehaviour "AWARE";
        _group setCombatMode "RED";

        // Leader -- distinguishing safari hat + tac vest.
        private _leaderPos = if (_bps isNotEqualTo []) then { _bps deleteAt 0 } else { _housePos getPos [2, random 360] };
        private _leader = _group createUnit ["O_Soldier_F", _leaderPos, [], 0, "NONE"];
        _leader setPosATL [_leaderPos select 0, _leaderPos select 1, (_leaderPos select 2) + 0.2];
        _leader setName _leaderName;
        _leader setVariable ["BO_exempt", true, true];
        _leader setCaptive false;
        _leader setUnitPos "MIDDLE";
        doStop _leader;
        _leader disableAI "PATH";

        removeAllWeapons _leader;
        removeUniform _leader;
        removeHeadgear _leader;
        removeGoggles _leader;
        removeBackpackGlobal _leader;
        removeAllAssignedItems _leader;
        removeAllItemsWithMagazines _leader;

        _leader forceAddUniform (selectRandom OT_CRIM_Clothes);
        _leader addHeadgear "H_Hat_Safari_olive_F";
        _leader addVest "V_TacVest_brn";
        private _lwpn = selectRandom OT_CRIM_Weapons;
        _leader addWeaponGlobal _lwpn;
        private _lmags = getArray (configFile >> "CfgWeapons" >> _lwpn >> "magazines");
        if (_lmags isNotEqualTo []) then {
            for "_m" from 1 to 6 do { _leader addMagazineGlobal (selectRandom _lmags) };
            _leader selectWeapon _lwpn;
        };
        _leader addEventHandler ["Dammaged", OT_fnc_EnemyDamagedHandler];

        // 4 CRIM bodyguards.
        for "_i" from 1 to 4 do {
            private _bp = if (_bps isNotEqualTo []) then { _bps deleteAt 0 } else { _housePos getPos [4 + (random 5), random 360] };
            private _u = _group createUnit ["O_Soldier_F", _bp, [], 0, "NONE"];
            _u setPosATL [_bp select 0, _bp select 1, (_bp select 2) + 0.2];
            _u setVariable ["BO_exempt", true, true];
            _u setCaptive false;

            removeAllWeapons _u;
            removeUniform _u;
            removeHeadgear _u;
            removeGoggles _u;
            removeBackpackGlobal _u;
            removeAllAssignedItems _u;
            removeAllItemsWithMagazines _u;

            _u forceAddUniform (selectRandom OT_CRIM_Clothes);
            _u addGoggles (selectRandom OT_CRIM_Goggles);
            private _gwpn = selectRandom OT_CRIM_Weapons;
            _u addWeaponGlobal _gwpn;
            private _gmags = getArray (configFile >> "CfgWeapons" >> _gwpn >> "magazines");
            if (_gmags isNotEqualTo []) then {
                for "_m" from 1 to 4 do { _u addMagazineGlobal (selectRandom _gmags) };
                _u selectWeapon _gwpn;
            };

            _u addEventHandler ["HandleDamage", {
                private _src = _this select 3;
                if (captive _src) then {
                    if (!isNull objectParent _src || (_src call OT_fnc_unitSeenNATO)) then {
                        _src setCaptive false;
                    };
                };
            }];
            _u addEventHandler ["Dammaged", OT_fnc_EnemyDamagedHandler];

            if (_i <= 2) then {
                _u setUnitPos "MIDDLE";
                doStop _u;
                _u disableAI "PATH";
            };
        };

        [_group, _housePos, 15] call CBA_fnc_taskDefend;

        missionNamespace setVariable [format ["BO_bounty_leader_%1", _jobid], _leader];
        missionNamespace setVariable [format ["BO_bounty_group_%1",  _jobid], _group];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        private _leader = missionNamespace getVariable [format ["BO_bounty_leader_%1", _jobid], objNull];
        if (isNull _leader) exitWith { false };
        !alive _leader
    },
    {
        params ["_jobid", "", "", "_townName", "_leaderName", "_reward", "_wassuccess"];

        private _group = missionNamespace getVariable [format ["BO_bounty_group_%1", _jobid], grpNull];

        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [[_group]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_bounty_leader_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_bounty_group_%1",  _jobid], nil];

        if (_wassuccess) then {
            [_reward, format ["Bounty: %1", _leaderName]] call OT_fnc_money;
            if (!isNil "OT_fnc_support") then {
                [_townName, 10, format ["Killed gang leader %1", _leaderName]] call OT_fnc_support;
            };
        };
    },
    _params
]
