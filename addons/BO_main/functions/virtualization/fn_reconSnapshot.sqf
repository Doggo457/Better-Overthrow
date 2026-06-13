#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconSnapshot
 *
 * Capture the current state of a NATO base so the next respawn
 * restores the same garrison layout. Called from fn_despawn just
 * before unit cleanup, for every base (persistence is universal --
 * not gated on recon).
 *
 * Entry shape (per snapshotted thing):
 *   [ typeOf, posATL, vecDir, vecUp, payload, kind, meta ]
 *
 *   kind = "INF": payload is the unit's saved loadout array.
 *                 meta is a hashmap with keys:
 *                   rank, behaviour, vcomNoPath, hvt, hvt_id, noai,
 *                   grp_vcm, grp_lambs
 *   kind = "VEH": payload is an array of crew entries, each
 *                 [crewType, role, turretPath, loadout]; role is
 *                 "DRIVER" | "GUNNER" | "COMMANDER" | "TURRET" |
 *                 "CARGO"; turretPath is the path array for TURRET.
 *                 An empty payload means the vehicle was uncrewed
 *                 (airgarrison, or rare uncrewed vehgarrison roll) --
 *                 restore leaves it uncrewed too.
 *                 meta is a hashmap with keys:
 *                   origin -- "VEH_VG" | "VEH_AIR" | "VEH_HMG"
 *                   grp_vcm, grp_lambs
 *
 * Vehicle ownership detection covers OT's three tagging patterns:
 *   - vehgarrison = _baseName on the vehicle (parked vehicles)
 *   - airgarrison = _baseName on the vehicle (parked aircraft)
 *   - garrison    = _baseName on the vehicle (rare; some special)
 *   - any crew has garrison = _baseName (HMG mounts where vanilla
 *     OT only tags the crew, not the vehicle)
 *
 * Crew that get captured under a vehicle's VEH entry are not
 * re-captured as standalone INF in the second pass (consumed list).
 * Crew of vehgarrison vehicles are vanilla-OT-buggy tagged with
 * garrison = "HQ" regardless of actual base; we ignore the tag and
 * trust the vehicle's vehgarrison/airgarrison var instead.
 *
 * Result lives at `server var "BO_reconLayout_<base>"`. Cleared by
 * BO_fnc_clearReconState when NATO retakes the base.
 *
 * Params:
 *   0: STRING - base name
 *   1: ARRAY  - groups/objects to walk (spawner registry entry)
 */

SERVER_ONLY;

params [
    ["_baseName", "", [""]],
    ["_objects",  [],  [[]]]
];

if (_baseName isEqualTo "") exitWith {};

// BO IMPROVEMENT: vanilla OT mis-tagged HVT/APC + vehgarrison crew
// with garrison/vehgarrison = "HQ" (the literal string), regardless
// of actual base. fn_despawn would then see "HQ" as a candidate and
// call snapshot for "HQ" against every base's groups, capturing the
// same vehicles twice (once under the real base, once under "HQ"),
// silently corrupting later restores. The retag fix in
// fn_spawnNATOObjective.sqf addresses the source, but legacy
// in-progress saves may still carry stray "HQ" tags -- safety-net it.
if (_baseName isEqualTo "HQ" && {!(OT_NATO_HQ isEqualTo "HQ")}) exitWith {
    BO_LOG_INFO("recon", "BO_fnc_reconSnapshot: ignoring stray 'HQ' tag");
};

private _entries = [];
private _consumed = [];

// Pass 1: vehicles. Any objNull that belongs to this base gets
// snapshotted as VEH with its full crew captured by seat role.
{
    if !(_x isEqualType objNull) then { continue };
    if (!alive _x) then { continue };
    if (_x isKindOf "CAManBase") then { continue };

    // BO: record which tag identified this vehicle so reconRestore can
    // reapply the *correct* tag and not drain the wrong base pool.
    // VEH_HMG vehicles are untagged in vanilla OT (only crew is tagged)
    // -- if we restore them with vehgarrison=<base>, the next despawn
    // would treat them as vehgarrison and re-snapshot incorrectly,
    // draining the vehgarrison<base> pool when crew mounts.
    private _origin = "";
    if ((_x getVariable ["vehgarrison", ""]) isEqualTo _baseName) then { _origin = "VEH_VG" };
    if (_origin isEqualTo "" && {(_x getVariable ["airgarrison", ""]) isEqualTo _baseName}) then { _origin = "VEH_AIR" };
    // Gate the "garrison"-tagged fallback so vehgarrison vehicles
    // already covered above are not double-snapshotted under a stray
    // base name. Only treat "garrison" as a vehicle tag if the vehicle
    // has no vehgarrison/airgarrison tag at all.
    if (_origin isEqualTo "" &&
        {(_x getVariable ["vehgarrison", ""]) isEqualTo ""} &&
        {(_x getVariable ["airgarrison", ""]) isEqualTo ""} &&
        {(_x getVariable ["garrison", ""]) isEqualTo _baseName}) then {
        _origin = "VEH_HMG";
    };
    if (_origin isEqualTo "") then {
        // HMG case: vehicle untagged but crew tagged for this base.
        if (((crew _x) findIf { (_x getVariable ["garrison", ""]) isEqualTo _baseName }) != -1) then {
            _origin = "VEH_HMG";
        };
    };
    if (_origin isEqualTo "") then { continue };

    private _crewSnap = [];
    {
        _x params ["_u", "_role", "_cargoIdx", "_turretPath", "_isPerson"];
        if (isNull _u) then { continue };
        if (!alive _u) then { continue };
        _crewSnap pushBack [typeOf _u, _role, _turretPath, getUnitLoadout _u];
        _consumed pushBack _u;
    } forEach (fullCrew _x);

    // BO: capture group-level flags so reconRestore can replay them
    // instead of hardcoding VCM_Disable/lambs_disable on every crew.
    private _grp = group ((crew _x) param [0, objNull]);
    private _meta = createHashMap;
    _meta set ["origin", _origin];
    _meta set ["grp_vcm", if (isNull _grp) then { false } else { _grp getVariable ["Vcm_Disable", false] }];
    _meta set ["grp_lambs", if (isNull _grp) then { false } else { _grp getVariable ["lambs_danger_disableGroupAI", false] }];

    _entries pushBack [
        typeOf _x,
        getPosATL _x,
        vectorDir _x,
        vectorUp _x,
        _crewSnap,
        "VEH",
        _meta
    ];
} forEach _objects;

// Pass 2: standalone infantry. Skip anyone consumed by a vehicle
// entry, anyone currently riding in a vehicle (the vehicle owns
// them), and anyone not tagged for this base.
{
    if !(_x isEqualType grpNull) then { continue };
    private _grp = _x;
    // BO: snapshot group-level flags so reconRestore can replay them
    // rather than hardcoding VCM_Disable on every restored group.
    private _grpVcm = _grp getVariable ["VCM_Disable", false];
    private _grpVcmAlt = _grp getVariable ["Vcm_Disable", false];
    private _grpVcmFlag = _grpVcm || _grpVcmAlt;
    private _grpLambs = _grp getVariable ["lambs_danger_disableGroupAI", false];
    {
        if (_x in _consumed) then { continue };
        if (!alive _x) then { continue };
        if ((_x getVariable ["garrison", ""]) isNotEqualTo _baseName) then { continue };
        if ((vehicle _x) isNotEqualTo _x) then { continue };

        // BO: capture per-unit state needed for a faithful restore --
        // rank, behaviour, VCOM_NOPATHING_Unit, HVT flags.
        private _meta = createHashMap;
        _meta set ["rank", rank _x];
        _meta set ["behaviour", behaviour _x];
        _meta set ["vcomNoPath", _x getVariable ["VCOM_NOPATHING_Unit", false]];
        _meta set ["hvt", _x getVariable ["hvt", false]];
        _meta set ["hvt_id", _x getVariable ["hvt_id", ""]];
        _meta set ["noai", _x getVariable ["NOAI", false]];
        _meta set ["grp_vcm", _grpVcmFlag];
        _meta set ["grp_lambs", _grpLambs];

        _entries pushBack [
            typeOf _x,
            getPosATL _x,
            vectorDir _x,
            vectorUp _x,
            getUnitLoadout _x,
            "INF",
            _meta
        ];
    } forEach (units _grp);
} forEach _objects;

// Skip empty writes. Vanilla OT mis-tags vehgarrison crew with
// `garrison = "HQ"` regardless of actual base, so fn_despawn picks
// up "HQ" as a candidate from any base that has vehgarrison crew.
// Snapshot is then called for "HQ" against that base's groups and
// finds nothing -- writing the empty result would clobber the real
// HQ snapshot. Empty = no-op handles that without special-casing.
if (_entries isEqualTo []) exitWith {
    private _skipMsg = format ["No tagged entities at %1 -- snapshot skipped", _baseName];
    BO_LOG_INFO("recon", _skipMsg);
};

server setVariable [format ["BO_reconLayout_%1", _baseName], _entries, true];

// BO HAL hook: every snapshot feeds the garrison-reinforcement
// bookkeeping (current strength + high-water target per base).
if (!isNil "BO_HAL_fnc_garrisonTargetNote") then {
    [_baseName, _entries] call BO_HAL_fnc_garrisonTargetNote;
};

private _msg = format ["Snapshotted %1 entries at %2", count _entries, _baseName];
BO_LOG_INFO("recon", _msg);
