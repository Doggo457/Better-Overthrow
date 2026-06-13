params ["_me", ["_killer", objNull]];

if !(local _me) exitWith {}; //Only run this on the machine where unit is local

if ((isNull _killer) || { _killer == _me }) then {
    private _aceSource = _me getVariable ["ace_medical_lastDamageSource", objNull];
    // BO fix: params declares the dying unit as _me, not _unit (was an
    // undefined-var ref that always evaluated to nil and threw).
    if ((!isNull _aceSource) && { _aceSource != _me }) then {
        _killer = _aceSource;
    };
};

// BO artillery: if the kill came from a player-tagged fire-mission
// shell or a CAS-tagged vehicle, capture the caller UID + type tag
// BEFORE the CAManBase substitution below collapses the ammo source
// into its driver (objNull for shells). We carry these through to
// BO_fnc_deathHandlerServer so it can apply the civilian-collateral
// standing penalty.
private _fmUID = "";
private _fmType = "";
if (!isNull _killer) then {
    private _src = _killer;
    if ((_src getVariable ["BO_playerFireMission", ""]) isNotEqualTo "") then {
        _fmUID = _src getVariable ["BO_playerFireMission", ""];
        _fmType = _src getVariable ["BO_fireMissionType", "FM"];
    } else {
        // CAS heli tag lives on the parent vehicle (the heli itself,
        // not the gunner/pilot AI).
        private _veh = vehicle _src;
        if (!isNull _veh && {(_veh getVariable ["BO_playerCASMission", ""]) isNotEqualTo ""}) then {
            _fmUID = _veh getVariable ["BO_playerCASMission", ""];
            _fmType = "CAS";
        };
    };
};

if !((typeOf _killer) isKindOf "CAManBase") then {
    _killer = driver _killer;
};

if (_killer call OT_fnc_unitSeen) then {
    _killer setCaptive false;
    _killer setVariable ["lastkill", time, true];
};

private _town = _me call OT_fnc_nearestTown;

if (isPlayer _me) exitWith {
    if !(_town in (server getVariable ["NATOabandoned", []])) then {
        [_town, 1] call OT_fnc_stability;
    } else {
        [_town, -1] call OT_fnc_stability;
    };
    _me setCaptive true;
};

private _civ = _me getVariable "civ";
private _garrison = _me getVariable "garrison";
private _employee = _me getVariable "employee";
private _vehgarrison = _me getVariable "vehgarrison";
private _polgarrison = _me getVariable "polgarrison";
private _airgarrison = _me getVariable "airgarrison";
private _criminal = _me getVariable "criminal";
private _crimleader = _me getVariable "crimleader";
private _hvt = _me getVariable "hvt_id";

private _standingChange = 0;

private _bounty = _me getVariable ["OT_bounty", 0];
if (_bounty > 0) then {
    [_killer, _bounty] call OT_fnc_rewardMoney;
    [_killer, _bounty] call OT_fnc_experience;
    _me setVariable ["OT_bounty", 0, false];
};

// MP race: the EH runs on whatever client owns the dying unit, so if
// two clients drop NATO soldiers in the same tick they both
// read-modify-write `server`-namespace counters (garrison/police/
// NATOresources/employ/vehgarrison/airgarrison) and clobber each
// other. We hoist all that shared-state RMW into
// BO_fnc_deathHandlerServer and remoteExec it to the server in a
// single batched call below. The client keeps the local-only work:
// kill counters on _killer, stability/money/exp/gangRep/support
// (those functions are MP-safe on their own).

private _typeOfMe = typeOf _me;
private _diff = server getVariable ["OT_difficulty", 1];

call {
    if (!isNil "_civ") exitWith {
        _killer setVariable ["CIVkills", (_killer getVariable ["CIVkills", 0]) + 1, true];
        _standingChange = -50;
        [_town, -1] call OT_fnc_stability;
    };
    if (!isNil "_hvt") exitWith {
        _killer setVariable ["BLUkills", (_killer getVariable ["BLUkills", 0]) + 1, true];
        [_killer, 250] call OT_fnc_experience;
        // Server handles: OT_NATOhvts removal, NATOresources drain,
        // and the all-clients notify broadcast.
    };
    if (!isNil "_employee") exitWith {
        _killer setVariable ["CIVkills", (_killer getVariable ["CIVkills", 0]) + 1, true];
        // BO fix: was format ["employ%1", _mobsterid] -- undefined
        // var, so the decrement always failed silently. The right
        // variable is _employee.
        // Server handles: decrement of employ%1 + notify broadcast.
    };
    if (!isNil "_criminal") exitWith {
        _killer setVariable ["OPFkills", (_killer getVariable ["OPFkills", 0]) + 1, true];
        private _hometown = _me getVariable ["hometown", ""];
        private _reward = 50;
        private _stability = 2;
        _standingChange = 1;
        // OT_civilians ledger scrub handled by the server function.

        [_hometown, _stability] call OT_fnc_stability;
        [_killer, _reward] call OT_fnc_rewardMoney;
        [_killer, 10] call OT_fnc_experience;
        private _gangid = _me getVariable ["OT_gangid", -1];
        [_killer, _gangid, -10] call OT_fnc_gangRep;
    };
    if (!isNil "_crimleader") exitWith {
        _killer setVariable ["OPFkills", (_killer getVariable ["OPFkills", 0]) + 1, true];
        private _gangid = _me getVariable ["OT_gangid", -1];
        private _hometown = _me getVariable ["hometown", ""];
        private _reward = 500 + ((round random 6) * 50);
        private _stability = 10;
        _standingChange = 10;
        // Gang dissolution + marker delete + cooldown handled by the
        // server function (single-locality RMW on OT_civilians).

        [_hometown, _stability] call OT_fnc_stability;
        [_killer, _reward] call OT_fnc_rewardMoney;
        [_killer, 50] call OT_fnc_experience;
        [_killer, _gangid, -25] call OT_fnc_gangRep;
    };
    if (!isNil "_polgarrison") exitWith {
        [_town, -2] call OT_fnc_stability;
        // Server handles: police%1 RMW, marker retext, notify.
    };
    if (!isNil "_garrison" || !isNil "_vehgarrison" || !isNil "_airgarrison") then {
        _killer setVariable ["BLUkills", (_killer getVariable ["BLUkills", 0]) + 1, true];
        if (!isNil "_garrison") then {
            // Server handles NATOresourceGain++ and garrison%1
            // decrement; we still drive stability locally.
            if (_garrison in OT_allTowns) then {
                _town = _garrison;
                [_killer, 10] call OT_fnc_experience;
            } else {
                [_killer, 25] call OT_fnc_experience;
            };
            private _townpop = server getVariable [format ["population%1", _town], 0];
            private _stab = -1;
            if (_townpop < 350 && (random 100) > 50) then {
                _stab = -2;
            };
            if (_townpop < 100) then {
                _stab = -3;
            };
            if (_garrison in OT_allTowns) then {
                [_garrison, _stab] call OT_fnc_stability;
            };
        };
        // vehgarrison / airgarrison list mutations live on the server.
    } else {
        if (side _me isEqualTo blufor) then {
            [_town, -1] call OT_fnc_stability;
        };
        if (side _me isEqualTo opfor) then {
            [_town, 1] call OT_fnc_stability;
        };
        if ((side _me isEqualTo independent) || captive _me) then {
            if !(_town in (server getVariable ["NATOabandoned", []])) then {
                [_town, 1] call OT_fnc_stability;
            } else {
                [_town, -1] call OT_fnc_stability;
            };
        };
    };
};

// Hand off all shared-state mutations to the server. Pack defaults so
// the server function can treat "" / -1 / false as "branch not taken".
private _hvtArg = if (isNil "_hvt") then { "" } else { _hvt };
private _employeeArg = if (isNil "_employee") then { "" } else { _employee };
private _criminalArg = !(isNil "_criminal");
private _crimleaderArg = !(isNil "_crimleader");
private _polArg = if (isNil "_polgarrison") then { "" } else { _polgarrison };
private _garArg = if (isNil "_garrison") then { "" } else { _garrison };
private _vehArg = if (isNil "_vehgarrison") then { "" } else { _vehgarrison };
private _airArg = if (isNil "_airgarrison") then { "" } else { _airgarrison };
private _cividArg = _me getVariable ["OT_civid", -1];
private _gangidArg = _me getVariable ["OT_gangid", -1];
private _hometownArg = _me getVariable ["hometown", ""];

[
    _typeOfMe,
    _town,
    _hvtArg,
    _employeeArg,
    _criminalArg,
    _cividArg,
    _gangidArg,
    _hometownArg,
    _crimleaderArg,
    _polArg,
    _garArg,
    _vehArg,
    _airArg,
    _diff,
    _fmUID,
    _fmType
] remoteExec ["BO_fnc_deathHandlerServer", 2, false];

if ((_killer call OT_fnc_unitSeen) || (_standingChange < -9)) then {
    _killer setCaptive false;
    if (!isNull objectParent _killer) then {
        {
            _x setCaptive false;
        } forEach (crew objectParent _killer);
    };
};
if (isPlayer _killer) then {
    if (_standingChange isEqualTo -50) then {
        [_town, _standingChange, "You killed a civilian", _killer] call OT_fnc_support;
    } else {
        [_town, _standingChange] call OT_fnc_support;
    };
} else {
    if (side _killer isEqualTo independent) then {
        [_town, _standingChange] call OT_fnc_support;
    };
};

// BO HAL hooks (guarded one-liners, build doc section 12):
// a NATO death feeds regional heat; the killer becomes a sighting at
// the kill site (ingest drops captive/unseen killers itself); and the
// doctrine engine takes its lesson (server-side: AI victims are
// server-local, which is the case that matters).
if (!isNil "BO_HAL_fnc_ingestSighting") then {
    if (side _me isEqualTo west) then {
        [getPosATL _me] call BO_HAL_fnc_noteLoss;
        if (isServer && {!isNull _killer} && {_killer isKindOf "Man"}
            && {side group _killer isEqualTo independent}) then {
            ["kill", _killer, _me] call BO_HAL_fnc_doctrineNote;
        };
    };
    if (!isNull _killer && {_killer isKindOf "Man"} && {side group _killer isEqualTo independent}) then {
        [_killer, getPosATL _killer, "death"] call BO_HAL_fnc_ingestSighting;
    };
};
