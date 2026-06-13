/*
    Author: ThomasAngel, ARMAZac

    Description:
    Loops through all radio towers and checks if they should be abandoned

    Parameters:
        -

    Usage: [] call OT_fnc_NATOabandonTowers;

    Returns: Boolean - was a radio tower abandoned
*/

private _countered = false;
private _abandoned = server getVariable ["NATOabandoned", []];
// Lint-found bug: _resources was decremented below but never defined
// (and never written back) -- the tower-loss budget hit silently
// errored every capture. Read + write the real ledger.
private _resources = server getVariable ["NATOresources", 2000];

{
    _x params ["_pos", "_name"];
    if !(_name in _abandoned) then {
        if ([_pos] call OT_fnc_inSpawnDistance) then {
            private _numMil = { side _x isEqualTo blufor } count (_pos nearEntities ["CAManBase", 300]);
            private _numRes = { side _x isEqualTo independent || captive _x } count (_pos nearEntities ["CAManBase", 100]);
            if (_numMil < _numRes) then {
                _abandoned pushBack _name;
                // BO HAL hook: losing a comm tower is a strategic slap.
                if (!isNil "BO_HAL_fnc_warLevelBump") then {
                    [0.5, "comm tower lost"] call BO_HAL_fnc_warLevelBump;
                };
                // BO fix (user report: "captured towers still have NATO
                // units around them"): the live garrison lingered after
                // capture because despawn never fires while players hold
                // the area. Strip their garrison tag -- the HAL field-
                // command pass adopts them as leaderless field troops
                // and marches them off to the nearest REAL base.
                {
                    if ((_x getVariable ["garrison", ""]) isEqualTo _name) then {
                        _x setVariable ["garrison", nil, false];
                    };
                } forEach ((_pos nearEntities [["CAManBase", "LandVehicle"], 350]) select {
                    side _x isEqualTo blufor || {side group _x isEqualTo blufor}
                });
                _name setMarkerColor "ColorGUER";
                format ["Resistance has captured the %1 tower", _name] remoteExec ["OT_fnc_notifyGood", 0, false];
                _resources = _resources - 100;
                _countered = true;
                format ["%1_restrict", _name] setMarkerAlpha 0;
            };
        };
    };
    if (_countered) exitWith {};
} forEach OT_NATOComms;

server setVariable ["NATOabandoned", _abandoned, true];
server setVariable ["NATOresources", _resources max 0, true];

_countered;
