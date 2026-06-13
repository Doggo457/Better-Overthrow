#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_garrisonSerialize
 *
 * Fold an arrived reinforcement convoy into a DESPAWNED base's
 * persistent-garrison snapshot (BO_reconLayout_<base>), then delete
 * the live objects. Entry shapes mirror BO_fnc_reconSnapshot exactly:
 *
 *   INF: [type, posATL, vecDir, vecUp, loadout, "INF", meta]
 *   VEH: [type, posATL, vecDir, vecUp, crewSnap, "VEH", meta]
 *        crewSnap: [[crewType, role, turretPath, loadout], ...]
 *
 * Units scatter onto sentry positions around the base anchor so the
 * restored layout looks garrisoned, not parade-ground. The transport
 * is folded in as a vehgarrison-origin VEH (it stays at the base --
 * the convoy "delivered" it).
 *
 * Params: 0: STRING base, 1: ARRAY base pos, 2: GROUP inf,
 *         3: OBJECT veh, 4: GROUP crew
 * Returns: NUMBER men folded in
 */

SERVER_ONLY;
params [
    ["_base", "", [""]],
    ["_pos", [], [[]]],
    ["_grp", grpNull, [grpNull]],
    ["_veh", objNull, [objNull]],
    ["_crewGrp", grpNull, [grpNull]]
];
if (_base isEqualTo "" || {_pos isEqualTo []}) exitWith { 0 };

private _key = format ["BO_reconLayout_%1", _base];
private _snap = server getVariable [_key, []];
private _added = 0;

// ---- infantry as sentries around the anchor --------------------------
private _foot = if (isNull _grp) then { [] } else {
    (units _grp) select { alive _x && { vehicle _x isEqualTo _x } }
};
{
    private _p = _pos getPos [8 + random 30, random 360];
    _p set [2, 0];
    private _meta = createHashMapFromArray [
        ["rank", rank _x],
        ["behaviour", "SAFE"],
        ["vcomNoPath", false],
        ["hvt", false],
        ["hvt_id", ""],
        ["noai", false],
        ["grp_vcm", true],
        ["grp_lambs", true]
    ];
    _snap pushBack [typeOf _x, _p, [random 1 - 0.5, random 1 - 0.5, 0], [0, 0, 1],
        getUnitLoadout _x, "INF", _meta];
    _added = _added + 1;
} forEach _foot;

// ---- the transport (with any still-mounted men as its crew) ----------
if (!isNull _veh && {alive _veh}) then {
    private _crewSnap = [];
    {
        _x params ["_u", "_role", "_cargoIdx", "_turretPath", "_isPerson"];
        if (!isNull _u && {alive _u}) then {
            _crewSnap pushBack [typeOf _u, _role, _turretPath, getUnitLoadout _u];
            _added = _added + ([0, 1] select (_role isEqualTo "CARGO"));
        };
    } forEach (fullCrew _veh);
    private _vp = _pos getPos [15 + random 20, random 360];
    _vp set [2, 0];
    private _vMeta = createHashMapFromArray [
        ["origin", "VEH_VG"],
        ["grp_vcm", true],
        ["grp_lambs", true]
    ];
    _snap pushBack [typeOf _veh, _vp, [0, 1, 0], [0, 0, 1], _crewSnap, "VEH", _vMeta];
};

server setVariable [_key, _snap, true];

// ---- delete the live objects (no player can see this -- the base is
// despawned, so nobody is within the spawn bubble) ---------------------
if (!isNull _grp) then {
    { deleteVehicle _x } forEach (units _grp);
    deleteGroup _grp;
};
if (!isNull _veh) then {
    { _veh deleteVehicleCrew _x } forEach (crew _veh);
    deleteVehicle _veh;
};
if (!isNull _crewGrp) then {
    { deleteVehicle _x } forEach (units _crewGrp);
    deleteGroup _crewGrp;
};

private _msg = format ["Garrison reinforced (serialized): +%1 men folded into %2 snapshot", _added, _base];
BO_LOG_INFO("hal", _msg);
_added
