#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconRestore
 *
 * Recreate a NATO base from a recon snapshot. Called from
 * fn_spawnNATOObjective at the top, in lieu of the random
 * findEmptyPosition rolls, when a saved layout exists for this base.
 *
 * Current snapshot format (BO_fnc_reconSnapshot):
 *   [ type, pos, vecDir, vecUp, payload, kind, meta ]
 *   kind = "INF" -> payload is loadout, meta carries rank/behaviour/
 *                   VCOM/HVT flags + group VCM/lambs flags.
 *   kind = "VEH" -> payload is [[crewType, role, turretPath, loadout], ...]
 *                   Empty crew list means the vehicle was originally
 *                   uncrewed (airgarrison) -- restore leaves it that way.
 *                   meta.origin is one of "VEH_VG" | "VEH_AIR" | "VEH_HMG"
 *                   and is the *only* tag reapplied on restore (we no
 *                   longer write vehgarrison on HMGs -- that would
 *                   drain the vehgarrison<base> pool when crew mounts).
 *
 * Backward-compat:
 *   - 6-element new format (no meta): restored with default behaviour
 *     and origin assumed VEH_VG (legacy behaviour).
 *   - 6-element old format with bool _isVehicle at index 5: restored
 *     as bare vehicles with createVehicleCrew (matches the pre-fix
 *     behavior).
 *
 * Groups:
 *   - One shared patrol group for all standalone infantry; resumes
 *     CBA_fnc_taskPatrol when the restore finishes.
 *   - One group per vehicle for its crew (so they stay seated; a
 *     vehicle's crew shouldn't taskPatrol off into the bush if the
 *     gunner gets killed).
 *
 * Params:
 *   0: ARRAY  - base position (_posTown)
 *   1: STRING - base name
 *   2: STRING - spawn id from the spawner registry
 *   3: ARRAY  - snapshot layout (BO_reconLayout_<base>)
 */

SERVER_ONLY;

params [
    ["_posTown",  [0,0,0], [[]]],
    ["_name",     "",      [""]],
    ["_spawnid",  "",      [""]],
    ["_layout",   [],      [[]]]
];

if (_layout isEqualTo []) exitWith {};

private _spawned = [];

// BO: defer creating the standalone-infantry patrol group until we
// know the snapshotted group-level flags from the first INF meta.
// Hardcoding VCM_Disable + lambs_disable on every restore (the
// pre-fix behaviour) ignored the original config: VCM_TOUGHSQUAD
// groups (from comms / regular spawn) want VCM enabled, not disabled.
private _infGroup = grpNull;
private _infGroupReady = false;

{
    // BO: meta is optional (legacy 6-element snapshots have no meta);
    // default to empty hashmap so getOrDefault calls below stay safe.
    _x params ["_type", "_pos", "_vecDir", "_vecUp", "_payload", "_kind"];
    private _meta = _x param [6, createHashMap];
    if !(_meta isEqualType createHashMap) then { _meta = createHashMap };

    // Old format detection: index 5 is bool _isVehicle.
    if (_kind isEqualType true) then {
        if (_kind) then {
            private _veh = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
            _veh setPosATL _pos;
            _veh setVectorDirAndUp [_vecDir, _vecUp];
            createVehicleCrew _veh;
            _veh setVariable ["garrison", _name, false];
            { _x setVariable ["garrison", _name, false] } forEach (crew _veh);
            _spawned pushBack _veh;
        } else {
            if (isNull _infGroup) then {
                _infGroup = createGroup [blufor, true];
                _infGroup setVariable ["VCM_Disable", true];
                _infGroup setVariable ["lambs_danger_disableGroupAI", true];
                _spawned pushBack _infGroup;
                _infGroupReady = true;
            };
            private _u = _infGroup createUnit [_type, _pos, [], 0, "NONE"];
            _u setPosATL _pos;
            _u setVectorDirAndUp [_vecDir, _vecUp];
            // BO HIGH FIX: initMilitary must run so HandleDamage /
            // Dammaged event handlers attach (captive-flag-strip needs
            // them) -- but BEFORE setUnitLoadout so the snapshot
            // loadout wins over initMilitary's random loadout.
            [_u, _name] call OT_fnc_initMilitary;
            if (_payload isNotEqualTo []) then { _u setUnitLoadout _payload };
            _u setVariable ["garrison", _name, false];
        };
        continue;
    };

    // New format
    if (_kind isEqualTo "VEH") then {
        // BO HIGH FIX: reapply only the tag origin recorded at snapshot
        // time. Tagging an HMG with vehgarrison would cause fn_despawn
        // to enrol it as a vehgarrison vehicle, then fn_initNATO
        // pre-populates vehgarrison<base> with HMG classes -- the pool
        // would drain on every despawn. VEH_HMG: tag only the crew.
        private _origin = _meta getOrDefault ["origin", "VEH_VG"];
        private _veh = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
        _veh setPosATL _pos;
        _veh setVectorDirAndUp [_vecDir, _vecUp];
        switch (_origin) do {
            case "VEH_VG":  { _veh setVariable ["vehgarrison", _name, false] };
            case "VEH_AIR": { _veh setVariable ["airgarrison", _name, false] };
            case "VEH_HMG": { /* no vehicle tag -- crew gets garrison below */ };
            default         { _veh setVariable ["vehgarrison", _name, false] };
        };
        _spawned pushBack _veh;

        if (_payload isEqualTo []) then {
            // Originally uncrewed (airgarrison etc.) -- leave it that way.
            continue;
        };

        // BO: replay group-level flags captured at snapshot time
        // instead of forcing VCM/lambs off.
        private _vGroup = createGroup [blufor, true];
        private _grpVcm = _meta getOrDefault ["grp_vcm", true];
        private _grpLambs = _meta getOrDefault ["grp_lambs", true];
        if (_grpVcm) then {
            _vGroup setVariable ["VCM_Disable", true];
            _vGroup setVariable ["Vcm_Disable", true, false];
        };
        if (_grpLambs) then { _vGroup setVariable ["lambs_danger_disableGroupAI", true] };
        _vGroup setBehaviour "SAFE";
        _spawned pushBack _vGroup;

        {
            _x params ["_cType", "_cRole", "_cTurretPath", "_cLoadout"];
            private _u = _vGroup createUnit [_cType, getPosATL _veh, [], 0, "NONE"];
            // BO HIGH FIX: initMilitary BEFORE setUnitLoadout so
            // HandleDamage event handlers attach and the snapshot
            // loadout overrides the random one.
            [_u, _name] call OT_fnc_initMilitary;
            if (_cLoadout isNotEqualTo []) then { _u setUnitLoadout _cLoadout };
            _u setVariable ["garrison", _name, false];

            switch (toUpper _cRole) do {
                case "DRIVER":    { _u moveInDriver _veh };
                case "GUNNER":    { _u moveInGunner _veh };
                case "COMMANDER": { _u moveInCommander _veh };
                case "TURRET":    {
                    // moveInTurret returns Nothing -- testing it threw.
                    // Verify the seat took by checking locality instead.
                    _u moveInTurret [_veh, _cTurretPath];
                    if ((vehicle _u) isNotEqualTo _veh) then { _u moveInCargo _veh };
                };
                default           { _u moveInCargo _veh };
            };
        } forEach _payload;
        continue;
    };

    // INF
    private _isHvt = _meta getOrDefault ["hvt", false];

    // BO: HVTs need their own GUARD/CYCLE-waypoint group -- they must
    // NOT join the shared patrol group (taskPatrol would walk them off
    // into the bush). Mirror the original HVT spawn block's group
    // shape: solo group, Vcm_Disable, GUARD then CYCLE.
    private _targetGroup = grpNull;
    if (_isHvt) then {
        _targetGroup = createGroup [blufor, true];
        _targetGroup setVariable ["Vcm_Disable", true, true];
        _spawned pushBack _targetGroup;
    } else {
        // Create the shared patrol group lazily using the first INF
        // entry's snapshotted group flags. Subsequent units inherit it.
        if (isNull _infGroup) then {
            _infGroup = createGroup [blufor, true];
            private _grpVcm = _meta getOrDefault ["grp_vcm", true];
            private _grpLambs = _meta getOrDefault ["grp_lambs", true];
            if (_grpVcm) then {
                _infGroup setVariable ["VCM_Disable", true];
                _infGroup setVariable ["Vcm_Disable", true, false];
            };
            if (_grpLambs) then { _infGroup setVariable ["lambs_danger_disableGroupAI", true] };
            _spawned pushBack _infGroup;
            _infGroupReady = true;
        };
        _targetGroup = _infGroup;
    };

    private _u = _targetGroup createUnit [_type, _pos, [], 0, "NONE"];
    _u setPosATL _pos;
    _u setVectorDirAndUp [_vecDir, _vecUp];
    // BO HIGH FIX: initMilitary BEFORE setUnitLoadout (see VEH path).
    [_u, _name] call OT_fnc_initMilitary;
    if (_payload isNotEqualTo []) then { _u setUnitLoadout _payload };
    _u setVariable ["garrison", _name, false];

    // BO IMPROVEMENT: replay per-unit state captured at snapshot --
    // rank/behaviour/VCOM_NOPATHING_Unit/HVT flags. Without this,
    // restored HVTs lose hvt/hvt_id/NOAI and become regular infantry.
    private _rank = _meta getOrDefault ["rank", ""];
    if (_rank isNotEqualTo "") then { _u setRank _rank };
    private _beh = _meta getOrDefault ["behaviour", ""];
    if (_beh isNotEqualTo "") then { _u setBehaviour _beh };
    if (_meta getOrDefault ["vcomNoPath", false]) then {
        _u setVariable ["VCOM_NOPATHING_Unit", true, false];
    };
    if (_isHvt) then {
        _u setVariable ["hvt", true, true];
        _u setVariable ["hvt_id", _meta getOrDefault ["hvt_id", ""], true];
    };
    if (_meta getOrDefault ["noai", false]) then {
        _u setVariable ["NOAI", true, true];
        _u disableAI "PATH";
        _u addEventHandler [
            "FiredNear",
            {
                params ["_unit"];
                _unit enableAI "PATH";
            }
        ];
    };

    // BO: give restored HVTs the same GUARD/CYCLE waypoints the
    // original spawn block sets up, so they hold their post.
    if (_isHvt) then {
        private _wp = _targetGroup addWaypoint [_pos, 0];
        _wp setWaypointType "GUARD";
        _wp = _targetGroup addWaypoint [_pos, 0];
        _wp setWaypointType "CYCLE";
        {
            _x addCuratorEditableObjects [units _targetGroup, false];
        } forEach (allCurators);
    };
} forEach _layout;

// Drop the patrol group if every snapshot entry was a vehicle.
if (!_infGroupReady) then {
    // Never created
} else {
    if ((count units _infGroup) isEqualTo 0) then {
        deleteGroup _infGroup;
        _spawned = _spawned - [_infGroup];
    } else {
        [_infGroup, _posTown, 75, 6] call CBA_fnc_taskPatrol;
    };
};

private _existing = spawner getVariable [_spawnid, []];
spawner setVariable [_spawnid, _existing + _spawned, false];

private _msg = format ["Restored %1 entries at %2 from recon snapshot", count _layout, _name];
BO_LOG_INFO("recon", _msg);
