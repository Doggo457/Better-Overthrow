params ["_mortar", "_mortarGroup"];

// Lambs is enabled - register the arty
if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
    [_mortarGroup] call lambs_wp_fnc_taskArtilleryRegister;
};

while {
    sleep (5 + (random 5));
    ("8Rnd_82mm_Mo_shells" in getArtilleryAmmo [_mortar]) && (alive _mortar) && ((units _mortarGroup) findIf { alive _x } != -1);
} do {
    private _attacking = server getVariable ["NATOattacking", ""];
    private _mortarpos = getPos _mortar;

    if (_attacking != "" && !(_attacking in OT_allTowns)) then {
        private _pos = server getVariable _attacking;
        private _distance = (_pos distance _mortar);

        private _timesince = time - (server getVariable ["NATOattackstart", time]);
        if (_timesince < 300) then {
            if (_distance < 4000 && _distance > 500) then {
                _mortarGroup setCombatMode "RED";
                private _p = _pos getPos [150, random 360];
                _mortar commandArtilleryFire [_p, "8Rnd_82mm_Mo_shells", 1];
                sleep (3 + (random 3));
                _mortar commandArtilleryFire [_p, "8Rnd_82mm_Mo_shells", 1];
                sleep 3;
                _mortarGroup setCombatMode "BLUE";
                //Did anyone hear that?
                if ((_mortarpos nearEntities ["CAManBase", 3000]) findIf { side _x isEqualTo independent || captive _x } != -1) then {
                    private _icons = spawner getVariable ["NATOmortars", []];
                    private _found = false;
                    {
                        if ((_x select 0) isEqualTo _mortarpos) exitWith {
                            private _range = (_x select 1) - round ((_x select 1) * 0.25);
                            _x set [1, _range];
                            _x set [2, _mortarpos getPos [_range, random 360]];
                        };
                    } forEach (_icons);
                    if !(_found) then {
                        _icons pushBack [_mortarpos, 1500, _mortarpos getPos [1500, random 360]];
                    };
                    spawner setVariable ["NATOmortars", _icons, true];
                };
            };
        };
    } else {
        private _targets = [spawner getVariable ["NATOknownTargets", []], [], { _x select 2 }, "DESCEND"] call BIS_fnc_sortBy;
        {
            _x params ["_ty", "_pos", "_pri", "", "_done"];
            private _distance = (_pos distance2D _mortar);
            private _town = _pos call OT_fnc_nearestTown;

            // Make sure we don't shell towns. The safezone around a town depends on the population
            private _towndist = _pos distance2D (server getVariable [_town, _pos]);
            private _safezone = 200 + ((server getVariable format ["population%1", _town]) / 2);

            if (!(_ty == "H" || _ty == "P" || _ty == "V")
                && _pri > 80
                && _towndist > _safezone
                && _distance < 4000
                && _distance > 250
            //&& _housedist > 75
                && !_done
            ) exitWith {
                _x set [4, true];
                _mortarGroup setCombatMode "RED";

                // The first shot must miss the target!!! Otherwise players just... die
                _mortar commandArtilleryFire [_pos getPos [30, random 360], "8Rnd_82mm_Mo_shells", 1];
                sleep (3 + (random 3));
                _mortar commandArtilleryFire [_pos, "8Rnd_82mm_Mo_shells", 1];
                sleep (3 + (random 3));
                _mortar commandArtilleryFire [_pos, "8Rnd_82mm_Mo_shells", 1];
                sleep 3;
                _mortarGroup setCombatMode "BLUE";
                //Did anyone hear that?
                if ((_mortarpos nearEntities ["CAManBase", 3000]) findIf { side _x isEqualTo independent || captive _x } != -1) then {
                    private _icons = spawner getVariable ["NATOmortars", []];
                    private _found = false;
                    {
                        if ((_x select 0) isEqualTo _mortarpos) exitWith {
                            private _range = (_x select 1) - round ((_x select 1) * 0.25);
                            _x set [1, _range];
                            _x set [2, _mortarpos getPos [_range, random 360]];
                        };
                    } forEach (_icons);
                    if !(_found) then {
                        _icons pushBack [_mortarpos, 1500, _mortarpos getPos [1500, random 360]];
                    };
                    spawner setVariable ["NATOmortars", _icons, true];
                };
            };
        } forEach (_targets);
        spawner setVariable ["NATOknownTargets", _targets, true];
    };
};
