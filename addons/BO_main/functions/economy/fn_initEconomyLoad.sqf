{ _x setMarkerAlpha 0 } forEach OT_regions;

//Find NATO HQ
{
    _x params ["_pos", "_name"];
    if (_name isEqualTo OT_NATO_HQ) then {
        OT_NATO_HQPos = _pos;
    };
} forEach (OT_objectiveData + OT_airportData);

private _allActiveShops = [];
private _allActiveCarShops = [];
private _allActivePiers = [];

private _version = server getVariable ["EconomyVersion", 0];

diag_log format ["Overthrow: Economy version is %1", _version];

//Generate 10 possible gang camp positions for each town

{
    private _town = _x;
    private _posTown = server getVariable _x;
    private _allpos = [];

    private _possible = selectBestPlaces [_posTown, 600, "(1 + forest + trees) * (1 - houses) * (1 - sea)", 10, 600];
    {
        private _pos = _x select 0;
        _pos set [2, 0];
        if (_pos isFlatEmpty [-1, -1, 0.5, 10] isNotEqualTo []) then {
            private _ob = _pos call OT_fnc_nearestObjective;
            private _obpos = _ob select 0;
            private _obdist = _obpos distance _pos;

            private _towndist = (server getVariable _town) distance _pos;
            private _control = _pos call OT_fnc_nearestCheckpoint;
            // If there are no checkpoints (Malden), use one million as distance.
            private _cdist = if (!isNil "_control") then { (getMarkerPos _control) distance _pos } else { 1000000 };

            if (_obdist > 800 && _towndist > 200 && _cdist > 500) then {
                _allpos pushBack _pos;
            };
        };
        if ((count _allpos) > 10) exitWith {};
    } forEach (_possible);
    spawner setVariable [format ["gangpositions%1", _town], _allpos, false];

    if ((server getVariable "StartupType") == "NEW") then {
        //Form gangs on a new game start
        private _stability = server getVariable [format ["stability%1", _town], 50];
        if (_stability < 50 && (selectRandom [1, 2, 3, 4]) isEqualTo 1) then {
            //Approx 1/4 of all towns < 50% will have a gang at start
            private _gangid = [_town, false] call OT_fnc_formGang;
            if (_gangid > -1) then {
                [_gangid, 1 + floor (random 2), false] call OT_fnc_addToGang;
            };
        };
    };

    private _garrison = server getVariable [format ['police%1', _town], 0];
    private _mrkid = format ["%1-police", _town];
    _mrkid setMarkerText format ["%1", _garrison];
} forEach (OT_allTowns);

if (_version < OT_economyVersion) then {
    diag_log "Overthrow: Economy version is old, regenerating towns";
    OT_allShops = [];

    {
        _x params ["_cls", "_name", "_side"];
        if (_side != 1) then {
            private _reppos = server getVariable [format ["factionrep%1", _cls], false];
            if !(_reppos isEqualType []) then {
                private _town = selectRandom OT_allTowns;
                if (_cls isEqualTo OT_spawnFaction) then { _town = server getVariable "spawntown" };
                private _posTown = server getVariable _town;
                private _building = [_posTown, OT_allHouses] call OT_fnc_getRandomBuilding;
                private _pos = _posTown;
                if !(_building isEqualType true) then {
                    _pos = selectRandom (_building call BIS_fnc_buildingPositions);
                    [_building, "system"] call OT_fnc_setOwner;
                    if (isNil "_pos") then {
                        _pos = [[[getPos _building, 20]]] call BIS_fnc_randomPos;
                    };
                } else {
                    _pos = [[[_posTown, 200]]] call BIS_fnc_randomPos;
                };
                server setVariable [format ["factionrep%1", _cls], _pos, true];
                server setVariable [format ["factionname%1", _cls], _name, true];
            };
        };
    } forEach (OT_allFactions);
    diag_log "Overthrow: Economy Load Complete";
};

//Save upgrade for existing factions > 0.7.5.1
{
    _x params ["_cls", "_name"];
    private _n = server getVariable [format ["factionname%1", _cls], ""];
    if (_n isEqualTo "") then {
        server setVariable [format ["factionname%1", _cls], _name, true];
    };
} forEach (OT_allFactions);

//Stability markers
{
    private _stability = server getVariable format ["stability%1", _x];
    private _posTown = server getVariable _x;
    private _pos = _posTown getPos [40, -90];
    private _mSize = 250;

    if (_x in OT_capitals) then {
        _mSize = 400;
    };

    private _mrk = createMarkerLocal [_x, _pos];
    _mrk setMarkerShapeLocal "ELLIPSE";
    _mrk setMarkerSizeLocal [_mSize, _mSize];

    private _abandoned = server getVariable ["NATOabandoned", []];
    if (_mrk in _abandoned) then {
        _mrk setMarkerColorLocal "ColorRed";
    } else {
        _mrk setMarkerColorLocal "ColorYellow";
    };

    if (_stability < 50) then {
        _mrk setMarkerAlpha 1.0 - (_stability / 50);
    } else {
        _mrk setMarkerAlpha 0;
    };
    _mrk = createMarkerLocal [format ["%1-abandon", _x], _pos];
    _mrk setMarkerShapeLocal "ICON";
    private _garrison = server getVariable [format ['police%1', _x], 0];
    if (_garrison > 0) then {
        _mrk setMarkerTypeLocal "OT_Police";
    } else {
        _mrk setMarkerTypeLocal "OT_Anarchy";
    };
    if (_stability < 50) then {
        _mrk setMarkerColorLocal "ColorOPFOR";
    } else {
        _mrk setMarkerColorLocal "ColorGUER";
    };
    if (_x in (server getVariable ["NATOabandoned", []])) then {
        _mrk setMarkerAlpha 1;
    } else {
        _mrk setMarkerAlpha 0;
    };

    if ((server getVariable ["EconomyVersion", 0]) < OT_economyVersion) then {
        [_x] call OT_fnc_setupTownEconomy;
    };

    private _shops = server getVariable [format ["activeshopsin%1", _x], []];
    _allActiveShops append _shops;

    private _carshops = server getVariable [format ["activecarshopsin%1", _x], []];
    _allActiveCarShops append _carshops;

    private _piers = server getVariable [format ["activepiersin%1", _x], []];
    _allActivePiers append _piers;
} forEach (OT_allTowns);

//Business Markers
OT_allEconomic = [];
{
    _x params ["_pos", "_name"];
    private _mrk = createMarkerLocal [_name, _pos];
    _mrk setMarkerShapeLocal "ICON";
    _mrk setMarkerTypeLocal "ot_Business";
    _mrk setMarkerColorLocal "ColorWhite";
    if (_name in (server getVariable ["GEURowned", []])) then { _mrk setMarkerColorLocal "ColorGUER" };
    _mrk setMarkerAlpha 0.8;
    OT_allEconomic pushBack _name;
    server setVariable [_name, _pos, true];
    cost setVariable [_name, _x, true];
} forEach (OT_economicData);

//Factory Marker
private _mrk = createMarkerLocal ["Factory", OT_factoryPos];
_mrk setMarkerShapeLocal "ICON";
_mrk setMarkerTypeLocal "ot_Factory";
_mrk setMarkerColorLocal "ColorWhite";
if ("Factory" in (server getVariable ["GEURowned", []])) then { _mrk setMarkerColorLocal "ColorGUER" };
_mrk setMarkerAlpha 0.8;

server setVariable ["EconomyVersion", OT_economyVersion, false];

OT_allActiveShops = _allActiveShops;
publicVariable "OT_allActiveShops";

OT_allActiveCarShops = _allActiveCarShops;
publicVariable "OT_allActiveCarShops";

OT_allActivePiers = _allActivePiers;
publicVariable "OT_allActivePiers";

OT_economyLoadDone = true;
publicVariable "OT_economyLoadDone";
