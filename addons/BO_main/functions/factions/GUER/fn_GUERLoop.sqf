GUER_faction_loop_data params ["_lastmin", "_lasthr", "_currentProduction", "_stabcounter", "_trackcounter"];

private _numplayers = count (allPlayers - (entities "HeadlessClient_F"));
if (_numplayers isEqualTo 0) exitWith {};

_trackcounter = _trackcounter + 1;
if (_trackcounter > 5) then {
    _trackcounter = 0;
    //save online player data, in case they crash
    {
        if (_x getVariable ["OT_newplayer", false]) then {
            _x setVariable ["OT_newplayer", false, true];
        };
        [_x] call OT_fnc_savePlayerData;
    } forEach (allPlayers - (entities "HeadlessClient_F"));

    private _track = [];
    {
        if (_x getVariable ["OT_spawntrack", false]) then {
            _track pushBack _x;
        };
    } forEach (allUnits);
    {
        if (_x getVariable ["OT_spawntrack", false]) then {
            _track pushBack _x;
        };
    } forEach (vehicles);
    spawner setVariable ["track", _track, false];
};

//Stop civilians from fleeing after 20 seconds
{
    if (_x getVariable ["fleeing", false]) then {
        if ((time - (_x getVariable ["fleeingstart", 0])) > 20) then {
            _x setVariable ["fleeing", false];
            _x setBehaviour "SAFE";
        };
    };
} forEach (groups civilian);

private _dead = count allDeadMen;
if (_dead > 150) then {
    format ["There are %1 dead bodies, loot them or clean via options", _dead] remoteExec ["OT_fnc_notifyMinor", 0, false];
};

{
    if (_x isEqualType grpNull) then {
        private _units = units _x;
        if (_units isEqualTo []) then {
            [_x] call OT_fnc_cleanupEmptyGroup;
        };
        {
            [_x] call OT_fnc_cleanupUnit;
        } forEach (_units);
    };
    if (_x isEqualType objNull) then {
        [_x] call OT_fnc_cleanupUnit;
    };
} forEach (spawner getVariable ["_noid_", []]);

{
    if ((_x isKindOf "Air") && { (alive _x) } && ((side _x) isEqualTo blufor) && (_x call OT_fnc_isRadarInRange) && { crew _x isNotEqualTo [] }) then {
        [_x, 2500] call OT_fnc_revealToResistance;
    };
} forEach (entities "Air");

if ((date select 3) != _lasthr) then {
    _lasthr = date select 3;
    private _wages = 0;
    {
        if (_x != "Factory") then {
            private _perhr = [OT_nation, "WAGE", 0] call OT_fnc_getPrice;
            private _num = server getVariable [format ["%1employ", _x], 0];
            private _enum = _num;
            if (_enum > 20) then {
                _enum = 20;
            };
            private _funds = [] call OT_fnc_resistanceFunds;
            private _towage = (_num * _perhr);
            if (_funds >= _towage) then {
                [-_towage] call OT_fnc_resistanceFunds;
                _wages = _wages + (_num * _perhr);
                private _data = _x call OT_fnc_getBusinessData;

                private _pos = _data select 0;
                private _outnum = 2 * _num;
                private _innum = 2 * _num;
                private _intotal = _innum;
                if (_num > 0) then {
                    if (count _data isEqualTo 2 && _x != "Factory") then {
                        private _income = _enum * 200;
                        [_income] call OT_fnc_resistanceFunds;
                    };
                    if (count _data isEqualTo 3) then {
                        private _input = _data select 2;
                        private _income = 0;
                        private _sellprice = round (([OT_nation, _input, 0] call OT_fnc_getSellPrice) * 1.2);
                        private _container = _pos nearestObject OT_item_CargoContainer;
                        if (_container isEqualTo objNull) then {
                            private _p = _pos findEmptyPosition [5, 100, OT_item_CargoContainer];
                            _container = OT_item_CargoContainer createVehicle _p;
                            [_container, (server getVariable ["generals", []]) select 0] call OT_fnc_setOwner;
                            clearWeaponCargoGlobal _container;
                            clearMagazineCargoGlobal _container;
                            clearBackpackCargoGlobal _container;
                            clearItemCargoGlobal _container;
                        };
                        {
                            private _stock = _x call OT_fnc_unitStock;
                            private _c = _x;
                            {
                                _x params ["_cls", "_amt"];
                                if (_cls isEqualTo _input) exitWith {
                                    if (_amt >= _innum) then {
                                        [_c, _cls, _innum] call CBA_fnc_removeItemCargo;
                                        _income = _income + (_sellprice * _innum);
                                    } else {
                                        [_c, _cls, _amt] call CBA_fnc_removeItemCargo;
                                        _innum = _innum - _amt;
                                        _income = _income + (_sellprice * _amt);
                                    };
                                };
                            } forEach (_stock);
                        } forEach (_pos nearObjects [OT_item_CargoContainer, 50]);
                        [_income] call OT_fnc_resistanceFunds;
                    };
                    if (count _data isEqualTo 4) then {
                        private _input = _data select 2;
                        private _output = _data select 3;
                        private _container = _pos nearestObject OT_item_CargoContainer;
                        if (_container isEqualTo objNull) then {
                            private _p = _pos findEmptyPosition [5, 100, OT_item_CargoContainer];
                            _container = OT_item_CargoContainer createVehicle _p;
                            [_container, (server getVariable ["generals", []]) select 0] call OT_fnc_setOwner;
                            clearWeaponCargoGlobal _container;
                            clearMagazineCargoGlobal _container;
                            clearBackpackCargoGlobal _container;
                            clearItemCargoGlobal _container;
                        };
                        if (_input != "") then {
                            private _inputnum = 0;
                            {
                                private _c = _x;
                                {
                                    _x params ["_cls", "_amt"];
                                    if (_cls isEqualTo _input) exitWith {
                                        if (_amt >= _innum) then {
                                            [_c, _cls, _innum] call CBA_fnc_removeItemCargo;
                                            _inputnum = _inputnum + _innum;
                                        } else {
                                            [_c, _cls, _amt] call CBA_fnc_removeItemCargo;
                                            _innum = _innum - _amt;
                                            _inputnum = _inputnum + _amt;
                                        };
                                    };
                                } forEach (_c call OT_fnc_unitStock);
                            } forEach (_pos nearObjects [OT_item_CargoContainer, 50]);
                            _outnum = round (_outnum * (_inputnum / _intotal));
                        };
                        if (_output != "" && _outnum > 0) then {
                            if (_output in ["OT_Sugarcane", "ACE_Banana"]) then {
                                private _foundFertilizer = false;
                                {
                                    private _c = _x;
                                    {
                                        _x params ["_cls", "_amt"];
                                        if (_cls isEqualTo "OT_Fertilizer") exitWith {
                                            [_c, _cls, 1] call CBA_fnc_removeItemCargo;
                                            _foundFertilizer = true;
                                        };
                                    } forEach (_c call OT_fnc_unitStock);
                                    if (_foundFertilizer) exitWith {};
                                } forEach (_pos nearObjects [OT_item_CargoContainer, 50]);
                                if (_foundFertilizer) then {
                                    // _output is the classname STRING; the integer
                                    // count is _outnum. Previous code "_output * 1.5"
                                    // was a String*Number type error spamming RPT.
                                    _outnum = round (_outnum * 1.5);
                                };
                            };
                            _container addItemCargoGlobal [_output, _outnum];
                        };
                    };
                };
            } else {
                format ["Resistance was unable to pay wages at %1", _x] remoteExec ["OT_fnc_notifyMinor", 0, false];
            };
        };
    } forEach (server getVariable ["GEURowned", []]);
};

if ((date select 4) != _lastmin) then {
    _lastmin = date select 4;

    if (!(call OT_fnc_generalIsOnline) && _dead > 300) then {
        format ["There are %1 dead bodies, initiating auto-cleanup", _dead] remoteExec ["OT_fnc_notifyMinor", 0, false];
        call OT_fnc_cleanDead;
    };

    //chance to reveal an FOB
    private _revealed = server getVariable ["revealedFOBs", []];
    {
        _x params ["_pos"];
        private _id = str _pos;
        private _town = _pos call OT_fnc_nearestTown;
        private _support = [_town] call OT_fnc_support;
        if (!(_id in _revealed) && (_support > (random 2000))) then {
            _revealed pushBack _id;
            private _mrkid = createMarkerLocal [format ["natofob%1", _id], _pos];
            _mrkid setMarkerShapeLocal "ICON";
            _mrkid setMarkerTypeLocal "mil_Flag";
            _mrkid setMarkerColorLocal "ColorBLUFOR";
            _mrkid setMarkerAlpha 1;
            format ["Citizens of %1 have revealed intelligence of a nearby NATO FOB", _town] remoteExec ["OT_fnc_notifyMinor", 0, false];
        };
    } forEach (server getVariable ["NATOfobs", []]);
    server setVariable ["revealedFOBs", _revealed, false];

    _stabcounter = _stabcounter + 1;
    private _abandoned = server getVariable ["NATOabandoned", []];

    if (_stabcounter >= 10) then {
        _stabcounter = 0;
        {
            private _town = _x;
            private _townpos = server getVariable _x;
            if !(_town in _abandoned) then {
                if ([_townpos] call OT_fnc_inSpawnDistance) then {
                    if ((_townpos nearEntities ["CAManBase", 600]) findIf { side _x isEqualTo blufor } != -1) then {
                        [_town, -1] call OT_fnc_stability;
                    };
                };
            } else {
                private _stabchange = 0;
                private _numcops = { side _x isEqualTo blufor } count (_townpos nearEntities ["CAManBase", 600]);
                if (_numcops > 0) then {
                    _stabchange = _stabchange - _numcops;
                };
                private _police = server getVariable [format ["police%1", _town], 0];
                if (_police > 0) then {
                    _stabchange = _stabchange + floor (_police / 2);
                };
                if (_stabchange != 0) then {
                    [_town, _stabchange] call OT_fnc_stability;
                };
            };
        } forEach (OT_allTowns);
    };

    if ("Chemical Plant" in _abandoned) then {
        private _chems = server getVariable ["reschems", 0];
        server setVariable ["reschems", _chems + 1, true];
    };

    // Multi-factory: the factory production tick has moved into a
    // dedicated CBA per-frame handler installed by BO_fnc_factoryLoop
    // (called from postInit). Each placed factory holds its own
    // queue / producing / producetime on the object; the PFH iterates
    // the BO_buildFactories registry with a budgeted round-robin so
    // N factories scale linearly without blocking this GUER loop.
    //
    // Nothing remains here -- the legacy single-factory block has
    // been deleted in full. See:
    //   functions/factories/fn_factoryLoop.sqf
    //   functions/factories/fn_factoryTick.sqf
    //   functions/factories/fn_factoryProduceOne.sqf

    {
        _x params ["_owner", "_name", "_unit", "_rank"];
        if (_unit isEqualType objNull) then {
            private _xp = _unit getVariable ["OT_xp", 0];
            private _player = spawner getVariable [_owner, objNull];
            if (_rank == "PRIVATE" && _xp > (OT_rankXP select 0)) then {
                _x set [3, "CORPORAL"];
                _unit setRank "CORPORAL";
                format ["%1 has been promoted to Corporal", _name select 0] remoteExec ["OT_fnc_notifyMinor", _player, false];
                _unit setSkill 0.3 + (random 0.3);
            };
            if (_rank == "CORPORAL" && _xp > (OT_rankXP select 1)) then {
                _x set [3, "SERGEANT"];
                _unit setRank "SERGEANT";
                format ["%1 has been promoted to Sergeant", _name select 0] remoteExec ["OT_fnc_notifyMinor", _player, false];
                _unit setSkill 0.4 + (random 0.3);
            };
            if (_rank == "SERGEANT" && _xp > (OT_rankXP select 2)) then {
                _x set [3, "LIEUTENANT"];
                _unit setRank "LIEUTENANT";
                format ["%1 has been promoted to Lieutenant", _name select 0] remoteExec ["OT_fnc_notifyMinor", _player, false];
                _unit setSkill 0.6 + (random 0.3);
            };
            if (_rank == "LIEUTENANT" && _xp > (OT_rankXP select 3)) then {
                _x set [3, "CAPTAIN"];
                _unit setRank "CAPTAIN";
                format ["%1 has been promoted to Captain", _name select 0] remoteExec ["OT_fnc_notifyMinor", _player, false];
                _unit setSkill 0.7 + (random 0.3);
            };
            if (_rank == "CAPTAIN" && _xp > (OT_rankXP select 4)) then {
                _x set [3, "MAJOR"];
                _unit setRank "MAJOR";
                format ["%1 has been promoted to Major", _name select 0] remoteExec ["OT_fnc_notifyMinor", _player, false];
                _unit setSkill 0.8 + (random 0.2);
            };
        };
    } forEach (server getVariable ["recruits", []]);
};
GUER_faction_loop_data = [_lastmin, _lasthr, _currentProduction, _stabcounter, _trackcounter];
