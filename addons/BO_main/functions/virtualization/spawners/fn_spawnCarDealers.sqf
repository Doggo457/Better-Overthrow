if (!isServer) exitWith {};

params ["_town", "_spawnid"];
sleep random 0.2;
private _shopkeeper = objNull;
private _activeshops = server getVariable [format ["activecarshopsin%1", _town], []];

private _groups = [];
{
    //find building for active shop
    private _pos = _x;
    private _building = nearestBuilding _pos;

    //create group for car dealer
    private _group = createGroup civilian;
    _group setBehaviour "CARELESS";
    _groups pushBack _group;

    //set start location based on building config
    private _start = _building buildingPos getNumber (configOf _building >> "ot_shopPos");
    if (isNil "_start" || { _start isEqualTo "" } || { _start isEqualTo "''" }) then { _start = _building buildingPos 0 };
    private _facing = 0;

    //spawn objects from building template
    private _tracked = _building call OT_fnc_spawnTemplate;
    private _vehs = _tracked select 0;
    {
        //check for counter object and if found set start position relative.
        if (typeOf _x == "Land_CashDesk_F") then {
            _start = _x getRelPos [0.8, 0];
            _facing = getDir _x - 180;
        };
        _groups pushBack _x;
    } forEach (_vehs);

    //create shopkeeper as member of group
    _shopkeeper = _group createUnit [OT_civType_carDealer, _start, [], 0, "CAN_COLLIDE"];

    _shopkeeper setDir (_facing);
    doStop _shopkeeper;
    _shopkeeper allowDamage false;
    _shopkeeper disableAI "MOVE";
    _shopkeeper disableAI "AUTOCOMBAT";
    _shopkeeper setVariable ["NOAI", true, false];
    _shopkeeper setVariable ["carshop", true, true];
    _shopkeeper setVariable ["shopcheck", true, true];
    [_shopkeeper] call OT_fnc_initCarDealer;

    sleep 0.5;
} forEach (_activeshops);

spawner setVariable [_spawnid, (spawner getVariable [_spawnid, []]) + _groups, false];
