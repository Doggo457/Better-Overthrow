if (!isServer) exitWith {};

sleep random 0.5;

params ["_town", "_spawnid"];
private _activeshops = server getVariable [format ["activepiersin%1", _town], []];

private _shopkeeper = objNull;

private _group = createGroup civilian;
_group setBehaviour "CARELESS";
private _groups = [_group];
{
    private _pos = _x;
    private _building = nearestBuilding _pos;

    private _dir = getDir _building;
    _shopkeeper = _group createUnit [OT_civType_carDealer, [_pos, [0, 0, 2]] call BIS_fnc_vectorAdd, [], 0, "NONE"];
    _shopkeeper disableAI "MOVE";
    _shopkeeper disableAI "AUTOCOMBAT";
    _shopkeeper setVariable ["NOAI", true, false];
    _shopkeeper setVariable ["shop", true, true];

    _shopkeeper setDir (_dir - 180);

    [_shopkeeper] call OT_fnc_initHarbor;
    _shopkeeper setVariable ["harbor", true, true];
    sleep 0.5;
} forEach (_activeshops);

spawner setVariable [_spawnid, (spawner getVariable [_spawnid, []]) + _groups, false];
