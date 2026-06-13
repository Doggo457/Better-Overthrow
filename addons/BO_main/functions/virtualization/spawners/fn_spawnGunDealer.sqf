if (!isServer) exitWith {};
sleep random 2;

params ["_town", "_spawnid"];
private _posTown = server getVariable _town;

private _groups = [];

private _gundealerpos = server getVariable format ["gundealer%1", _town];
if (isNil "_gundealerpos") then {
    private _building = [_posTown, OT_gunDealerHouses] call OT_fnc_getRandomBuilding;
    if !(_building isEqualType true) then {
        _gundealerpos = selectRandom (_building call BIS_fnc_buildingPositions);
        [_building, "system"] call OT_fnc_setOwner;
    } else {
        _gundealerpos = [[[_posTown, 200]]] call BIS_fnc_randomPos;
    };
    server setVariable [format ["gundealer%1", _town], _gundealerpos, true];
};
private _group = createGroup civilian;
_groups pushBack _group;

_group setBehaviour "CARELESS";
private _dealer = _group createUnit [OT_civType_gunDealer, _gundealerpos, [], 0, "NONE"];

[_dealer] call OT_fnc_initGunDealer;

_dealer setVariable ["shopcheck", true, true];
_dealer setVariable ["gundealer", true, true];
spawner setVariable [format ["gundealer%1", _town], _dealer, true];
sleep 0.3;

spawner setVariable [_spawnid, (spawner getVariable [_spawnid, []]) + _groups, false];
