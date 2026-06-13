/*
 * BO mission: Collaborator Burglary
 *
 * A collaborator's townhouse holds a $5000 cash crate guarded by
 * 3 CRIM (hired bandit) bodyguards -- NOT NATO, so the host town
 * can be any town, friendly or NATO-held. Player kills the
 * guards, picks up the cash crate via addAction, and the loot
 * auto-deposits to bank.
 *
 * Reward: $5000 to the looter's bank, paid immediately on pickup
 * via BO_fnc_bankAdjust. End block pays no additional reward.
 *
 * Bandits dressed in OT_CRIM_Clothes/Weapons; OPFOR side (east)
 * so OT IND patrols in friendly towns may engage them.
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
    if (count _bps >= 3) then { _validHouses pushBack _h };
} forEach _houses;
if (_validHouses isEqualTo []) exitWith { [] };

private _house = selectRandom _validHouses;
private _housePos = getPosATL _house;
private _cashAmount = 5000;

private _title = format ["Burglary in %1", _townName];
private _description = format [
    "A known collaborator has $%1 stashed in their townhouse in %2. A few hired guns (CRIM bandits) are watching the place. Get in, kill them, take the cash crate -- the loot auto-deposits to your bank.<br/><br/>Reward: $%1 (bank deposit). The owner is collaborating with NATO; no civilian fallout.",
    _cashAmount, _townName
];

private _params = [_jobid, _house, _housePos, _townName, _cashAmount];

[
    [_title, _description],
    _housePos,
    {
        params ["_jobid", "_house", "_housePos"];

        private _hGroundZ = (getPosATL _house) select 2;
        private _bps = (_house buildingPos -1) select {
            !(_x isEqualTo [0,0,0])
                && ((_x select 2) - _hGroundZ) < 1.8
                && !(surfaceIsWater [_x select 0, _x select 1])
        };
        _bps = _bps call BIS_fnc_arrayShuffle;

        private _cratePos = if (_bps isNotEqualTo []) then { _bps deleteAt 0 } else { _housePos getPos [2, random 360] };
        private _crate = createVehicle ["Land_Suitcase_F", _cratePos, [], 0, "NONE"];
        _crate setPosATL [_cratePos select 0, _cratePos select 1, (_cratePos select 2) + 0.7];
        _crate setVariable ["BO_exempt", true, true];

        private _act = _crate addAction [
            "<t color='#80ff80'>Take Cash ($5000)</t>",
            {
                params ["_t", "_caller", "_jobid"];
                missionNamespace setVariable [format ["BO_burglary_picked_%1", _jobid], true, true];
                private _uid = getPlayerUID _caller;
                [_uid, 5000, "Collaborator Burglary"] remoteExec ["BO_fnc_bankAdjust", 2, false];
                deleteVehicle _t;
                "Cash deposited to your bank." call OT_fnc_notifyGood;
            },
            _jobid,
            1.5,
            true,
            true,
            "",
            "_this distance _target < 2.5 && (vehicle _this isEqualTo _this)"
        ];

        // 3 CRIM bandit guards.
        private _group = createGroup [east, true];
        _group setVariable ["VCM_TOUGHSQUAD", true, true];
        _group setBehaviour "AWARE";
        _group setCombatMode "RED";

        for "_i" from 1 to 3 do {
            private _bp = if (_bps isNotEqualTo []) then { _bps deleteAt 0 } else { _housePos getPos [3 + (random 4), random 360] };
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
            private _wpn = selectRandom OT_CRIM_Weapons;
            _u addWeaponGlobal _wpn;
            private _mags = getArray (configFile >> "CfgWeapons" >> _wpn >> "magazines");
            if (_mags isNotEqualTo []) then {
                for "_m" from 1 to 4 do { _u addMagazineGlobal (selectRandom _mags) };
                _u selectWeapon _wpn;
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

        missionNamespace setVariable [format ["BO_burglary_crate_%1",  _jobid], _crate];
        missionNamespace setVariable [format ["BO_burglary_group_%1",  _jobid], _group];
        missionNamespace setVariable [format ["BO_burglary_picked_%1", _jobid], false];
        missionNamespace setVariable [format ["BO_burglary_action_%1", _jobid], _act];
        true
    },
    {
        false
    },
    {
        params ["_jobid"];
        missionNamespace getVariable [format ["BO_burglary_picked_%1", _jobid], false]
    },
    {
        params ["_jobid", "", "", "_townName"];

        private _crate = missionNamespace getVariable [format ["BO_burglary_crate_%1",  _jobid], objNull];
        private _group = missionNamespace getVariable [format ["BO_burglary_group_%1",  _jobid], grpNull];
        private _act   = missionNamespace getVariable [format ["BO_burglary_action_%1", _jobid], -1];

        if (!isNull _crate && _act >= 0) then { _crate removeAction _act };
        if (!isNull _group) then {
            { _x setVariable ["BO_exempt", false, true] } forEach (units _group);
        };
        [[_group, _crate]] call BO_fnc_logMissionDebris;

        missionNamespace setVariable [format ["BO_burglary_crate_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_burglary_group_%1",  _jobid], nil];
        missionNamespace setVariable [format ["BO_burglary_picked_%1", _jobid], nil];
        missionNamespace setVariable [format ["BO_burglary_action_%1", _jobid], nil];

        // No reward in end block: payout happens in the pickup addAction
        // via BO_fnc_bankAdjust so the player gets paid immediately on
        // grabbing the crate.
    },
    _params
]
