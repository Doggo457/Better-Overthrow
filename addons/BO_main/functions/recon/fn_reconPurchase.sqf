#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconPurchase
 *
 * Server-authoritative purchase handler for paid recon flights.
 *
 * Re-validates standing + overlap (cash was already deducted client-side
 * via OT_fnc_money before the remoteExec). Registers a new entry in
 * BO_activeRecon on the server namespace (rides the standard saveGame
 * "server" loop), bumps NATOresources to model the drone-noticed pull,
 * audits under AUDIT_INTEL, and tells the owning client to arm its
 * local reveal layer.
 *
 * Params:
 *   0: STRING - ownerUID (steam UID of the buying player)
 *   1: STRING - scope    ("TOWN" | "REGION" | "MAP")
 *   2: STRING - scopeKey (town name | objective/airport name | "")
 *   3: NUMBER - cost     (already deducted on the client; audited only)
 */

SERVER_ONLY;

params [
    ["_ownerUID", "", [""]],
    ["_scope", "TOWN", [""]],
    ["_scopeKey", "", [""]],
    ["_cost", 0, [0]]
];

private _validScopes = ["TOWN", "REGION", "MAP"];
REQUIRE(_ownerUID isNotEqualTo "", "reconPurchase: empty ownerUID", nil);
REQUIRE(_scope in _validScopes, "reconPurchase: bad scope", nil);

// Resolve the owning player object once -- used for notify-routing and
// the arm remoteExec. May be objNull if the player disconnected between
// the click and the server tick; in that case we silently drop the
// entry rather than locking a refund up in the void.
private _ownerObj = (allPlayers select { getPlayerUID _x isEqualTo _ownerUID }) param [0, objNull];
private _ownerName = if (isNull _ownerObj) then { "" } else { name _ownerObj };

private _active = server getVariable ["BO_activeRecon", []];
private _dupIdx = _active findIf {
    ((_x select 0) isEqualTo _ownerUID)
    && {(_x select 1) isEqualTo _scope}
    && {(_x select 2) isEqualTo _scopeKey}
};
if (_dupIdx != -1) exitWith {
    if (!isNull _ownerObj) then {
        ["Recon overlaps existing active flight in this area"] remoteExec ["OT_fnc_notifyBad", _ownerObj, false];
        // Refund -- the client already deducted cash optimistically.
        if (_cost > 0) then { [_cost] remoteExec ["OT_fnc_money", _ownerObj, false] };
    };
    private _logMsg = format ["Recon purchase rejected (overlap): uid=%1 scope=%2 key=%3", _ownerUID, _scope, _scopeKey];
    BO_LOG_WARN("intel", _logMsg);
};

// Re-check standing server-side. TOWN/REGION use the bound town's rep;
// MAP uses the global rep counter.
private _stand = call {
    if (_scope isEqualTo "TOWN") exitWith {
        server getVariable [format ["rep%1", _scopeKey], 0]
    };
    if (_scope isEqualTo "REGION") exitWith {
        private _objPos = [];
        {
            _x params ["_p", "_n"];
            if (_n isEqualTo _scopeKey) exitWith { _objPos = _p };
        } forEach (OT_objectiveData + OT_airportData);
        private _town = if (_objPos isEqualTo []) then { "" } else { _objPos call OT_fnc_nearestTown };
        server getVariable [format ["rep%1", _town], 0]
    };
    server getVariable ["rep", 0]
};

private _minStand = missionNamespace getVariable ["BO_reconStandingMin", 50];
if (_stand < _minStand) exitWith {
    if (!isNull _ownerObj) then {
        private _msg = format ["Standing too low (%1 / need %2)", _stand, _minStand];
        [_msg] remoteExec ["OT_fnc_notifyBad", _ownerObj, false];
        // Refund -- the client already deducted cash optimistically.
        if (_cost > 0) then { [_cost] remoteExec ["OT_fnc_money", _ownerObj, false] };
    };
    private _logMsg = format ["Recon purchase rejected (standing): uid=%1 scope=%2 standing=%3 need=%4", _ownerUID, _scope, _stand, _minStand];
    BO_LOG_WARN("intel", _logMsg);
};

private _durMin = missionNamespace getVariable ["BO_reconDurationMinutes", 10];

// expireDate is the in-game date snapshot at expiry. 1 game minute is
// (1 / timeMultiplier) real minutes; BIS_fnc_addDaytime adds hours.
// The world-clock date is the PERSISTED truth: serverTime resets each
// mission launch, but `date` is captured + setDate-restored on load.
private _hoursAhead = (_durMin * timeMultiplier) / 60;
private _expireDate = [date, _hoursAhead] call BIS_fnc_addDaytime;

// Derive the session-local serverTime expiry from the world-clock delta.
// dateToNumber returns a fraction-of-year, so (delta-years * 365.25 * 86400)
// = game-seconds; divide by timeMultiplier to convert to real-seconds,
// which is the unit of serverTime. Runtime consumers (sweep / PFH / HUD)
// read this; BO_fnc_reconRebaseServerTimes re-derives it after each load.
private _expNum = dateToNumber _expireDate;
private _nowNum = dateToNumber date;
// dateToNumber wraps at New Year (fraction WITHIN the year); a purchase
// minutes before midnight Dec 31 yields _expNum < _nowNum. Unwrap.
if (_expNum < _nowNum) then { _expNum = _expNum + 1 };
private _expireServerTime = serverTime + ((_expNum - _nowNum) * 365.25 * 86400) / timeMultiplier;

_active pushBack [_ownerUID, _scope, _scopeKey, _expireServerTime, _expireDate, _cost];
server setVariable ["BO_activeRecon", _active, true];

// Bump NATOresources -- the drone scan didn't go unnoticed.
private _natoTick = missionNamespace getVariable ["BO_reconNATOResourceTick", 50];
private _res = server getVariable ["NATOresources", 0];
server setVariable ["NATOresources", _res + _natoTick, true];

// Audit.
private _desc = format ["Recon purchased: scope=%1 key=%2 cost=$%3 expires=%4", _scope, _scopeKey, _cost, _expireDate];
[AUDIT_INTEL, _desc, [_scope, _scopeKey, _cost, _expireDate], _ownerUID, _ownerName] call BO_fnc_auditServer;

// Server-side reveal pass. `OT_fnc_revealToResistance` iterates
// `groups independent`, which is server-local; calling from the
// client would be a no-op against the actual resistance AI. Compute
// the same scan centre/radius the client uses, scan candidates here,
// then reveal them in server scope.
private _scanCenter = [0, 0, 0];
private _scanRadius = 0;
call {
    if (_scope isEqualTo "TOWN") exitWith {
        {
            _x params ["_p", "_n"];
            if (_n isEqualTo _scopeKey) exitWith { _scanCenter = _p };
        } forEach OT_townData;
        _scanRadius = 600;
    };
    if (_scope isEqualTo "REGION") exitWith {
        {
            _x params ["_p", "_n"];
            if (_n isEqualTo _scopeKey) exitWith { _scanCenter = _p };
        } forEach (OT_objectiveData + OT_airportData);
        _scanRadius = 1500;
    };
    _scanCenter = [worldSize / 2, worldSize / 2, 0];
    _scanRadius = worldSize;
};
private _serverCandidates = (allUnits + vehicles) select {
    (alive _x)
    && {(side _x) isEqualTo blufor}
    && {(_x distance2D _scanCenter) < _scanRadius}
    && {
        (_x isKindOf "CAManBase")
        || (_x isKindOf "Car")
        || (_x isKindOf "Tank")
        || (_x isKindOf "Air")
        || (_x isKindOf "Ship")
    }
};
if (count _serverCandidates > 200) then { _serverCandidates resize 200 };
{ [_x, 2500] call OT_fnc_revealToResistance } forEach _serverCandidates;

// Tell the owner's client to build the local reveal layer (markers + HUD).
if (!isNull _ownerObj) then {
    [_scope, _scopeKey, _expireServerTime] remoteExec ["BO_fnc_reconClientArm", _ownerObj, false];
};

private _logMsg = format ["Recon registered: uid=%1 scope=%2 key=%3 cost=$%4 dur=%5min", _ownerUID, _scope, _scopeKey, _cost, _durMin];
BO_LOG_INFO("intel", _logMsg);
