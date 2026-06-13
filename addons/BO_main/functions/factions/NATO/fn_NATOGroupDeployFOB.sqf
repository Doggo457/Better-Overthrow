private _leader = _this;

private _group = group _leader;
private _targetPos = _leader getVariable ["OT_targetPos", objNull];
private _veh = vehicle _leader;

private _near = false;

{
    unassignVehicle _x;
} forEach (units _group);
(units _group) allowGetIn false;

sleep 10;
if ((units _group) findIf { alive _x } == -1) exitWith {};

if (!isNull _veh) then { deleteVehicle _veh };

private _fobs = server getVariable ["NATOfobs", []];

{
    private _pb = _x select 0;
    if (_pb distance _targetPos < 500) then {
        _near = true;
    };
} forEach (_fobs);
if (_near) exitWith {};

OT_flag_NATO createVehicle _targetPos;

_fobs pushBack [_targetPos, count units _group, []];
server setVariable ["NATOfobs", _fobs, true];
_group call OT_fnc_initMilitaryPatrol;
