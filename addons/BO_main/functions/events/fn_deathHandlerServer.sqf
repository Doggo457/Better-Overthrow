#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_deathHandlerServer
 *
 * Server-authoritative half of the death handler. The client-local
 * OT_fnc_deathHandler runs on whichever machine owned the dying unit
 * (its EntityKilled EH fires only where the unit is local). Anything
 * that read-modify-writes shared `server`-namespace counters has to
 * run in a single locality, otherwise simultaneous kills on two
 * clients clobber each other's increments on `NATOresources`,
 * `NATOresourceGain`, `employ%1`, `police%1`, `garrison%1`,
 * `vehgarrison%1`, `airgarrison%1`, and the `OT_NATOhvts` /
 * `OT_civilians` namespaces.
 *
 * The client packs the relevant per-victim getVariables and remoteExecs
 * here; this function does the RMW on `server` plus the
 * notify-everyone broadcasts so we don't get duplicate notifyMinor
 * spam if a kill is co-witnessed.
 *
 * Params (single array):
 *   0: STRING - dying unit typeOf (for vehgarrison/airgarrison list removal)
 *   1: STRING - nearest-town name
 *   2: ANY    - _hvt id, or nil-marker "" if not an HVT
 *   3: STRING - _employee key, or "" if not an employee
 *   4: BOOL   - _criminal? (true if dying unit was a criminal)
 *   5: SCALAR - _civid (-1 if n/a)
 *   6: SCALAR - _gangid (-1 if n/a)
 *   7: STRING - _hometown ("" if n/a)
 *   8: BOOL   - _crimleader?
 *   9: STRING - _polgarrison key ("" if n/a)
 *  10: STRING - _garrison key ("" if n/a)
 *  11: STRING - _vehgarrison key ("" if n/a)
 *  12: STRING - _airgarrison key ("" if n/a)
 *  13: SCALAR - difficulty (passed through so we don't read it again)
 *
 * Returns: nothing.
 */

SERVER_ONLY;

params [
    ["_typeOf", "", [""]],
    ["_town", "", [""]],
    ["_hvt", "", ["", 0]],
    ["_employee", "", [""]],
    ["_criminal", false, [false]],
    ["_civid", -1, [0]],
    ["_gangid", -1, [0]],
    ["_hometown", "", [""]],
    ["_crimleader", false, [false]],
    ["_polgarrison", "", [""]],
    ["_garrison", "", [""]],
    ["_vehgarrison", "", [""]],
    ["_airgarrison", "", [""]],
    ["_diff", 1, [0]],
    ["_fmUID", "", [""]],
    ["_fmType", "", [""]]
];

// HVT: remove from list, drain NATOresources by difficulty-scaled amount.
if (!(_hvt isEqualTo "")) then {
    private _idx = 0;
    {
        if ((_x select 0) isEqualTo _hvt) exitWith {};
        _idx = _idx + 1;
    } forEach (OT_NATOhvts);
    if (_idx < count OT_NATOhvts) then {
        OT_NATOhvts deleteAt _idx;
    };
    format ["A high-ranking NATO officer has been killed"] remoteExec ["OT_fnc_notifyMinor", 0, false];
    private _resources = server getVariable ["NATOresources", 0];
    _resources = _resources - 500;
    if (_diff isEqualTo 1) then { _resources = _resources - 500 };
    if (_diff isEqualTo 0) then { _resources = _resources - 1000 };
    if (_resources < 250) then { _resources = 250 };
    server setVariable ["NATOresources", _resources, true];
};

// Employee: decrement town employment counter, broadcast notice.
if (!(_employee isEqualTo "")) then {
    private _key = format ["employ%1", _employee];
    private _pop = server getVariable [_key, 0];
    if (_pop > 0) then {
        server setVariable [_key, _pop - 1, true];
    };
    format ["An employee of %1 has died", _employee] remoteExec ["OT_fnc_notifyMinor", 0, false];
};

// Criminal: scrub the OT_civilians ledger entry + drop the civid out
// of their gang's member list.
if (_criminal) then {
    if (_civid > -1) then {
        OT_civilians setVariable [format ["%1", _civid], nil, true];
        if (_gangid > -1) then {
            private _gang = OT_civilians getVariable [format ["gang%1", _gangid], []];
            if (_gang isNotEqualTo []) then {
                private _members = _gang select 0;
                _members deleteAt (_members find _civid);
                _gang set [0, _members];
                OT_civilians setVariable [format ["gang%1", _gangid], _gang, true];
            };
        };
    };
};

// Crim-leader: dissolve the whole gang, clear the town's gangs list,
// kill the gang marker and stamp a no-spawn cooldown.
if (_crimleader) then {
    if (_gangid > -1) then {
        private _gang = OT_civilians getVariable [format ["gang%1", _gangid], []];
        if (_gang isNotEqualTo []) then {
            private _name = _gang select 8;
            OT_civilians setVariable [format ["gang%1", _gangid], nil, true];
            private _gangs = OT_civilians getVariable [format ["gangs%1", _hometown], []];
            _gangs deleteAt (_gangs find _gangid);
            OT_civilians setVariable [format ["gangs%1", _hometown], _gangs, true];
            format ["The leader of %2 in %1 has been eliminated", _hometown, _name] remoteExec ["OT_fnc_notifyMinor", 0, false];
            if (!isNil "spawner") then {
                spawner setVariable [format ["nogang%1", _hometown], time + 3600, false];
            };
            private _mrkid = format ["gang%1", _hometown];
            deleteMarker _mrkid;
        };
    };
};

// Police: drop the town police count, retag the police marker.
if (!(_polgarrison isEqualTo "")) then {
    private _key = format ["police%1", _polgarrison];
    private _pop = server getVariable [_key, 0];
    if (_pop > 0) then {
        _pop = _pop - 1;
        server setVariable [_key, _pop, true];
        format ["A police officer has been killed in %1", _polgarrison] remoteExec ["OT_fnc_notifyMinor", 0, false];
    };
    private _mrkid = format ["%1-police", _polgarrison];
    _mrkid setMarkerText format ["%1", _pop];
};

// Foot garrison: NATOresourceGain++, drop garrison%1 count.
if (!(_garrison isEqualTo "")) then {
    server setVariable ["NATOresourceGain", (server getVariable ["NATOresourceGain", 0]) + 1, true];
    private _key = format ["garrison%1", _garrison];
    private _pop = server getVariable [_key, 0];
    if (_pop > 0) then {
        _pop = _pop - 1;
        server setVariable [_key, _pop, true];
    };
};

// Vehicle garrison: remove typeOf from the town's vehicle list.
if (!(_vehgarrison isEqualTo "")) then {
    private _key = format ["vehgarrison%1", _vehgarrison];
    private _vg = server getVariable [_key, []];
    private _i = _vg find _typeOf;
    if (_i >= 0) then {
        _vg deleteAt _i;
        server setVariable [_key, _vg, false];
    };
};

// Air garrison: same idea, separate list.
if (!(_airgarrison isEqualTo "")) then {
    private _key = format ["airgarrison%1", _airgarrison];
    private _vg = server getVariable [_key, []];
    private _i = _vg find _typeOf;
    if (_i >= 0) then {
        _vg deleteAt _i;
        server setVariable [_key, _vg, false];
    };
};

// BO artillery: civilian collateral from a player-tagged fire mission
// or CAS strike. Only fires when the kill was a civilian (_civid > -1
// indicates a real civilian ledger entry) and not a criminal /
// criminal leader (those branches already short-circuit above and
// reward the killer). Penalty value comes from BO_artilleryCivPenalty
// mission param, read here so the live param value applies.
if (_fmUID isNotEqualTo "" && {_civid > -1} && {!_criminal} && {!_crimleader}) then {
    private _penalty = missionNamespace getVariable ["BO_artilleryCivPenalty", -5];
    if (_hometown isNotEqualTo "") then {
        [_hometown, _penalty] call OT_fnc_support;
    };
    private _auditMsg = format ["Civilian killed by %1 (caller %2) penalty=%3 town=%4",
        _fmType, _fmUID, _penalty, _hometown];
    [AUDIT_ARTILLERY,
        _auditMsg,
        [_fmType, _fmUID, _penalty, _hometown, _civid],
        "",
        ""
    ] call BO_fnc_auditServer;

    // Route notification back to the caller via their owner ID
    // (remoteExec wants a net ID, not a UID string).
    private _callerIdx = allPlayers findIf { getPlayerUID _x isEqualTo _fmUID };
    if (_callerIdx >= 0) then {
        private _callerOwner = owner (allPlayers select _callerIdx);
        private _notify = format ["Civilian killed by %1 fire mission -- standing %2",
            _fmType, _penalty];
        _notify remoteExec ["OT_fnc_notifyBad", _callerOwner, false];
    };
};
