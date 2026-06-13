#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_spawnInformant
 *
 * Spawn a tagged civilian "informant" at a random building in the
 * named town. Registers the event on BO_activeCivilianEvents,
 * places local markers on every client (JIP-true), schedules the
 * natural-expiry cleanup and an MPKilled cleanup handler.
 *
 * Server-only.
 *
 * Params:
 *   0: STRING - town name (must be in OT_allTowns)
 *
 * Returns: ARRAY [eventId, town, npc, expiryDateNum, markerId] or []
 *          on failure.
 */

if (!isServer) exitWith {[]};

params [["_town", "", [""]]];
if (_town isEqualTo "") exitWith {[]};

private _posTown = server getVariable [_town, []];
if (_posTown isEqualTo []) exitWith {
    private _msg = format ["spawnInformant: no posTown for %1", _town];
    BO_LOG_WARN("civilian", _msg);
    []
};

private _building = [_posTown, OT_allHouses] call OT_fnc_getRandomBuilding;
private _destination = if (isNil "_building" || {isNull _building}) then {
    _posTown getPos [random 200, random 360]
} else {
    private _positions = _building call BIS_fnc_buildingPositions;
    if (_positions isEqualTo []) then {
        _posTown getPos [random 200, random 360]
    } else {
        _positions call BIS_fnc_selectRandom
    };
};
if (isNil "_destination" || {_destination isEqualTo [0,0,0]}) then {
    _destination = _posTown getPos [random 200, random 360];
};

private _counter = (missionNamespace getVariable ["BO_civilianEventCounter", 0]) + 1;
missionNamespace setVariable ["BO_civilianEventCounter", _counter];
private _eventId = format ["BO_civEvt_%1", _counter];
private _markerId = format ["BO_civEvt_mrk_%1", _counter];

private _group = createGroup [civilian, true];
private _civ = _group createUnit [OT_civType_local, _destination, [], 0, "NONE"];
if (isNull _civ) exitWith {
    private _msg = format ["spawnInformant failed in %1", _town];
    BO_LOG_WARN("civilian", _msg);
    deleteGroup _group;
    []
};

_civ allowDamage true;
_civ disableAI "MOVE";
_civ disableAI "AUTOCOMBAT";
_civ setVariable ["NOAI", true, false];
_civ setVariable ["BO_isInformant", true, true];
_civ setVariable ["BO_informantEventId", _eventId, true];
_civ setVariable ["BO_informantTown", _town, true];
_civ setVariable ["notalk", true, true];
// Mark as unowned so OT save filters skip it. Informants are
// intentionally ephemeral; we never want them serialized.
_civ setVariable ["OT_forceSaveUnowned", false, true];

// Lifetime = N in-game minutes (param-configurable, default 20).
// Real-world seconds = in-game seconds / time multiplier.
private _lifetime = (missionNamespace getVariable ["BO_civilianEventLifetime", 20]) * 60;
private _accel = if (isNil "OT_timeMultiplier") then { 1.0 } else { OT_timeMultiplier };
if (_accel <= 0) then { _accel = 1.0 };
private _realLifetime = _lifetime / _accel;
// dateToNumber returns a fractional year; lifetime / seconds-per-year
// is a valid delta to add.
private _expiryDateNum = (dateToNumber date) + (_lifetime / (365 * 24 * 3600));
_civ setVariable ["BO_informantExpiry", _expiryDateNum, true];

// Register on the server registry.
private _active = server getVariable ["BO_activeCivilianEvents", []];
_active pushBack [_eventId, _town, _civ, _expiryDateNum, _markerId];
server setVariable ["BO_activeCivilianEvents", _active, true];

// Marker + notification: remoteExec to every client, JIP-true so
// late joiners get it too (but our explicit JIP handler in
// fn_civilianEventOnConnect is the authoritative replayer because
// CBA's onPlayerConnected can fire before the engine queues these).
[_markerId, _destination, _town] remoteExec ["BO_fnc_civilianEventMarker", 0, true];

private _notify = format ["%1: an informant has been spotted, find them before they leave", _town];
_notify remoteExec ["OT_fnc_notifyMinor", 0, false];

// Schedule the natural-expiry cleanup.
[{
    params ["_eventId"];
    [_eventId, "expired"] call BO_fnc_civilianEventCleanup;
}, [_eventId], _realLifetime] call CBA_fnc_waitAndExecute;

// MPKilled -> immediate cleanup, no reward.
_civ addMPEventHandler ["MPKilled", {
    params ["_unit"];
    private _eid = _unit getVariable ["BO_informantEventId", ""];
    if (_eid isEqualTo "") exitWith {};
    [_eid, "killed"] remoteExec ["BO_fnc_civilianEventCleanup", 2, false];
}];

private _auditMsg = format ["Informant spawned in %1", _town];
[AUDIT_CIVILIAN, _auditMsg, [_town, getPosATL _civ, _eventId], "", ""] call BO_fnc_auditServer;

[_eventId, _town, _civ, _expiryDateNum, _markerId]
