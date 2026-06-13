#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_casDialog
 *
 * Client-local. Stage 1 of the CAS flow: lists CAS-loadout helis
 * parked within 40m of the helipad, lets the player pick one, then
 * chains into BO_fnc_casPickTarget for the map click.
 *
 * Cooldown re-check at dialog open so a co-player race between the
 * action condition tick and the click doesn't slip a second dispatch
 * through. The server (BO_fnc_callCAS) also re-checks.
 *
 * Params:
 *   0: OBJECT - the helipad
 */

params [["_helipad", objNull, [objNull]]];
if (isNull _helipad) exitWith {};

private _casCd = missionNamespace getVariable ["BO_casCooldownSec", 1200];
private _last = _helipad getVariable ["BO_lastCASMission", 0];
if ((serverTime - _last) < _casCd) exitWith {
    private _msg = format ["CAS ready in %1s", round (_last + _casCd - serverTime)];
    _msg call OT_fnc_notifyMinor;
};

if (isNil "BO_casLoadouts") exitWith {
    "CAS system not initialised" call OT_fnc_notifyBad;
};

private _supportedClasses = keys BO_casLoadouts;
private _candidates = ((getPosATL _helipad) nearObjects ["Helicopter", 40]) select {
    alive _x && {(typeOf _x) in _supportedClasses}
};
if (_candidates isEqualTo []) exitWith {
    "No CAS-capable helicopter parked nearby" call OT_fnc_notifyBad;
};

missionNamespace setVariable ["BO_casHelipad", _helipad];

private _opts = [];
_opts pushBack "<t align='center' size='1.1'>Request CAS</t><br/><t align='center' size='0.7'>Pick aircraft</t>";
{
    private _veh = _x;
    private _cls = typeOf _veh;
    private _cost = BO_casLoadouts getOrDefault [_cls, 8000];
    private _costFmt = [_cost, 1, 0, true] call CBA_fnc_formatNumber;
    private _displayName = _cls call OT_fnc_vehicleGetName;
    private _label = format ["%1 ($%2)", _displayName, _costFmt];
    _opts pushBack [
        _label,
        {
            params ["_veh", "_cost"];
            missionNamespace setVariable ["BO_casVehClass", typeOf _veh];
            missionNamespace setVariable ["BO_casCost", _cost];
            [] call BO_fnc_casPickTarget;
        },
        [_veh, _cost]
    ];
} forEach _candidates;
_opts pushBack ["Cancel", {}];
_opts call OT_fnc_playerDecision;
