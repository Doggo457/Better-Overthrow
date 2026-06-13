#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_reclaimAssault
 *
 * LAST STAND (user-locked): NATO holds ZERO bases, so every 2 real
 * hours a heavy air assault launches from off-map (the carrier group
 * narrative) against a RANDOM rebel-held base to retake it as a
 * staging point:
 *
 *   - 2x cargo helicopters, each carrying a full squad (SL + 6)
 *   - 1x attack helicopter on SAD over the objective
 *   - jet support (OT_NATO_Vehicles_AirWingedSupport) on a SAD pass
 *   - drone support (CAS drone if the modset has one, else Darter ISR)
 *
 * Troop helis use the normal op machinery (kind "hot": the helo-drop
 * choreography in fn_evaluateOp lands and unloads them; retreats and
 * refunds apply normally -- they exfil to the SPAWN EDGE origin).
 *
 * A monitor script watches the objective for up to 45 min: when no
 * rebel is left within 350m and NATO boots stand within 400m, the base
 * flips back (NATOabandoned -, marker recolored, notifications), and
 * the survivors become its garrison -- serialized into the persistent
 * BO_reconLayout snapshot when unobserved, or tagged live when players
 * are watching.
 *
 * All classes from OT_NATO_* / mined pools: multi-nation.
 */

SERVER_ONLY;
if (missionNamespace getVariable ["BO_reclaimActive", false]) exitWith {};

private _abandoned = server getVariable ["NATOabandoned", []];
private _targets = ((missionNamespace getVariable ["OT_objectiveData", []])
    + (missionNamespace getVariable ["OT_airportData", []])) select {
    (_x select 1) in _abandoned
};
if (_targets isEqualTo []) exitWith {};

missionNamespace setVariable ["BO_reclaimActive", true];

(selectRandom _targets) params ["_pos", "_name"];
private _center = [worldSize / 2, worldSize / 2, 0];
private _origin = _center getPos [(worldSize * 0.7), _center getDir _pos];
_origin set [2, 0];

private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
private _sl = missionNamespace getVariable ["OT_NATO_Unit_SquadLeader", ""];
private _heliCls = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport_Large", ""];
if (_heliCls isEqualTo "") then {
    private _arr = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport", []];
    _heliCls = if (_arr isEqualType "") then { _arr } else { _arr param [0, ""] };
};
if (_heliCls isEqualTo "" || {_pool isEqualTo []}) exitWith {
    missionNamespace setVariable ["BO_reclaimActive", false];
};

private _newOp = {
    params ["_grp", "_veh", "_crewGrp", "_aim", "_pkgTag"];
    private _opId = (server getVariable ["BO_HAL_opCounter", 0]) + 1;
    server setVariable ["BO_HAL_opCounter", _opId];
    _grp setVariable ["BO_HAL_op", _opId, false];
    _grp setVariable ["initialStrength", ({ alive _x } count units _grp) max 1, false];
    if (!isNull _crewGrp && {_crewGrp isNotEqualTo _grp}) then {
        _crewGrp setVariable ["BO_HAL_op", _opId, false];
    };
    BO_HAL_activeOps pushBack [
        _opId, _pkgTag, _grp, _veh, _crewGrp, +_aim, +_origin,
        serverTime, "transit", ({ alive _x } count units _grp) max 1, 0, 0, "hot",
        serverTime, []
    ];
    _opId
};

// ---- 2x heliborne squads ---------------------------------------------
private _waveGrps = [];
for "_w" from 0 to 1 do {
    private _classes = [_sl];
    for "_i" from 1 to 6 do { _classes pushBack (selectRandom _pool) };
    _classes = _classes select { _x isNotEqualTo "" };
    private _aim = _pos getPos [120, (_w * 180) + random 60];
    ([_origin, _aim, _classes, _heliCls, "air", false] call BO_HAL_fnc_spawnGroup)
        params ["_g", "_h", "_c"];
    if (!isNull _g) then {
        [_g, true] call BO_HAL_fnc_dressGroup;
        [_g, _h, _c, _aim, "RECLAIM_SQUAD"] call _newOp;
        _waveGrps pushBack _g;
    };
};
if (_waveGrps isEqualTo []) exitWith {
    missionNamespace setVariable ["BO_reclaimActive", false];
};

// ---- attack helicopter over the objective -----------------------------
private _atkPool = missionNamespace getVariable ["OT_NATO_Vehicles_AirSupport", []];
if (_atkPool isNotEqualTo []) then {
    private _h = createVehicle [selectRandom _atkPool, [_origin select 0, _origin select 1, 250], [], 0, "FLY"];
    _h flyInHeight 180;
    _h setVariable ["BO_HAL_unit", true, false];
    createVehicleCrew _h;
    private _hg = group ((crew _h) param [0, objNull]);
    if (!isNull _hg) then {
        [_hg, false] call BO_HAL_fnc_dressGroup;
        _hg setBehaviour "COMBAT"; _hg setCombatMode "RED";
        private _wp = _hg addWaypoint [_pos, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointCompletionRadius 250;
        [_hg, _h, _hg, _pos, "RECLAIM_GUNSHIP"] call _newOp;
    };
};

// ---- jet pass ----------------------------------------------------------
private _jetPool = missionNamespace getVariable ["OT_NATO_Vehicles_AirWingedSupport", []];
if (_jetPool isNotEqualTo []) then {
    private _j = createVehicle [selectRandom _jetPool, [_origin select 0, _origin select 1, 600], [], 0, "FLY"];
    _j flyInHeight 500;
    _j setVariable ["BO_HAL_unit", true, false];
    createVehicleCrew _j;
    private _jg = group ((crew _j) param [0, objNull]);
    if (!isNull _jg) then {
        [_jg, false] call BO_HAL_fnc_dressGroup;
        _jg setBehaviour "COMBAT"; _jg setCombatMode "RED";
        private _wpj = _jg addWaypoint [_pos, 0];
        _wpj setWaypointType "SAD";
        _wpj setWaypointCompletionRadius 600;
        [_jg, _j, _jg, _pos, "RECLAIM_JET"] call _newOp;
    };
};

// ---- drone support -------------------------------------------------------
private _catalog = call BO_HAL_fnc_packageCatalog;
private _dIdx = _catalog findIf { (_x select 0) isEqualTo "AIR_CAS_DRONE" };
private _dPick = if (_dIdx >= 0 && {[_catalog select _dIdx] call BO_HAL_fnc_packageEligible}) then {
    _catalog select _dIdx
} else {
    private _r = _catalog findIf { (_x select 0) isEqualTo "RECON_DRONE" };
    if (_r >= 0) then { _catalog select _r } else { [] }
};
if (_dPick isNotEqualTo []) then {
    // Budget-neutral (last stand shouldn't die to an empty wallet).
    server setVariable ["NATOresources", (server getVariable ["NATOresources", 0]) + (_dPick select 1), true];
    [_dPick, _pos, "recon"] call BO_HAL_fnc_launchPackage;
};

(format ["NATO is mounting a major air assault to retake %1!", _name])
    remoteExec ["OT_fnc_notifyBig", 0, false];
["reclaim_launch", [_name]] call BO_HAL_fnc_aar;
[0.5, "last-stand assault"] call BO_HAL_fnc_warLevelBump;

// ---- objective monitor ----------------------------------------------------
[_pos, _name, _waveGrps] spawn {
    params ["_pos", "_name", "_waveGrps"];
    private _t0 = serverTime;
    private _won = false;
    while { (serverTime - _t0) < 2700 } do {
        sleep 60;
        private _bootsOn = (_waveGrps findIf {
            !isNull _x && {((units _x) findIf { alive _x && {(_x distance2D _pos) < 400} }) != -1}
        }) != -1;
        if (!_bootsOn) exitWith {};   // the wave is dead or gone
        private _rebels = ((_pos nearEntities [["CAManBase"], 350]) findIf {
            alive _x && {side group _x isEqualTo independent} && {!captive _x}
        }) != -1;
        if (_bootsOn && {!_rebels}) exitWith { _won = true };
    };

    if (_won) then {
        private _ab = server getVariable ["NATOabandoned", []];
        _ab = _ab - [_name];
        server setVariable ["NATOabandoned", _ab, true];
        _name setMarkerColor "ColorBLUFOR";
        (format ["NATO has RETAKEN %1 and established a staging point", _name])
            remoteExec ["OT_fnc_notifyBig", 0, false];
        ["reclaim_success", [_name]] call BO_HAL_fnc_aar;
        [1, "staging point retaken"] call BO_HAL_fnc_warLevelBump;

        // Survivors become the garrison: serialize into the persistent
        // snapshot when unobserved, else tag live and hand to the
        // field-command leash.
        private _watched = ((allPlayers select { alive _x }) findIf {
            (_x distance2D _pos) < OT_spawnDistance
        }) != -1;
        {
            private _g = _x;
            if (!isNull _g && {({ alive _x } count units _g) > 0}) then {
                private _oid = _g getVariable ["BO_HAL_op", -1];
                private _idx = BO_HAL_activeOps findIf { (_x select 0) isEqualTo _oid };
                if (_idx >= 0) then { BO_HAL_activeOps deleteAt _idx };
                if (_watched) then {
                    { _x setVariable ["garrison", _name, false] } forEach (units _g);
                    _g setVariable ["BO_HAL_op", nil, false];
                    _g setVariable ["BO_HAL_role", "garrison", false];
                    _g setVariable ["BO_HAL_anchor", +_pos, false];
                } else {
                    [_name, _pos, _g, objNull, grpNull] call BO_HAL_fnc_garrisonSerialize;
                };
            };
        } forEach _waveGrps;
    } else {
        ["reclaim_failed", [_name]] call BO_HAL_fnc_aar;
    };
    missionNamespace setVariable ["BO_reclaimActive", false];
};
