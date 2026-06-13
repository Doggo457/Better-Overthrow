#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pickHotPackage
 *
 * Threat-matched package selection (the soul of the design) + V7
 * tempo jitter: at high tempo HAL occasionally over-commits one rung,
 * at low tempo it under-commits -- the player feels intent, not a
 * lookup table.
 *
 * Params: 0: ARRAY NATOknownTargets entry (7-slot)
 * Returns: ARRAY catalog entry, or [] when nothing eligible.
 */

SERVER_ONLY;
params [["_sighting", [], [[]]]];
if (_sighting isEqualTo []) exitWith { [] };

private _kit  = _sighting param [6, []];
private _role = if (_kit isEqualType [] && {count _kit > 3}) then { _kit select 3 } else { "infantry" };
private _pos  = _sighting param [1, [0,0,0]];

// Urban vs rural drives the light-infantry split.
private _town = _pos call OT_fnc_nearestTown;
private _urban = false;
if (!isNil "_town" && {_town isEqualType ""} && {_town isNotEqualTo ""}) then {
    private _tpos = server getVariable [_town, []];
    if (_tpos isNotEqualTo []) then { _urban = (_tpos distance2D _pos) < 350 };
};

// Sighting near a registered player FOB => fortified-position response.
private _nearFob = ((server getVariable ["bases", []]) findIf {
    ((_x select 0) distance2D _pos) < 450
}) != -1;

// Escalation ladder per observed role, ordered heavy -> light. The
// first eligible entry wins; ineligible rungs fall through (locked
// decision #17: respond lighter rather than spawn wrong).
//
// WL-aware variety: at higher war levels the matched rung shifts up a
// weight class and the CAS drone (WL>=5 via catalog) enters the
// ladders -- EXCEPT against AA-capable kit, where sending a drone is
// feeding it. AT-capable kit gets the inverse treatment: drones first,
// because a Titan AT tube can't answer them.
private _wl = round (server getVariable ["BO_warLevel", 1]);

private _ladder = switch (true) do {
    case (_role in ["MBT"]):                          { ["HEAVY_ARMOR", "AIR_ATTACK", "AIR_CAS_DRONE", "LIGHT_ARMOR", "MED_SQUAD"] };
    case (_role in ["heli-attack", "jet", "heli-light"]): { ["AIR_LIGHT", "AIR_ATTACK", "MED_SQUAD"] };
    case (_role in ["IFV"]):                          { ["LIGHT_ARMOR", "AIR_CAS_DRONE", "AIR_ATTACK", "HEAVY_ARMOR", "MED_SQUAD"] };
    case (_role in ["AA-capable"]):                   { ["MED_SQUAD", "FORTIFIED_POSITION", "LGT_INFANTRY"] };
    case (_role in ["AT-capable"]):                   { ["AIR_CAS_DRONE", "MED_SQUAD", "LGT_INFANTRY"] };
    case (_role in ["transport-armed"]):              { ["LIGHT_ARMOR", "AIR_CAS_DRONE", "MED_SQUAD"] };
    case (_role in ["sniper"]):                       { ["LGT_INFANTRY_RURAL", "MED_SQUAD"] };
    case (_nearFob):                                  { ["FORTIFIED_POSITION", "AIR_ASSAULT", "MED_SQUAD", "LGT_INFANTRY"] };
    case (_urban && {_wl >= 4}):                      { ["MED_SQUAD", "AIR_ASSAULT", "FORTIFIED_POSITION", "LGT_INFANTRY"] };
    case (_urban):                                    { ["LGT_INFANTRY", "MED_SQUAD"] };
    case (_wl >= 4):                                  { ["MED_SQUAD", "AIR_ASSAULT", "LGT_INFANTRY_RURAL", "LGT_INFANTRY"] };
    default                                           { ["LGT_INFANTRY_RURAL", "LGT_INFANTRY", "MED_SQUAD"] };
};

// ---- adaptive counter-doctrine (locked #34) -------------------------
// The network profiles HOW the resistance fights (fn_doctrineTraits)
// and reshapes the response before it ever launches.
(missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]])
    params ["_tSniper", "_tCqb", "_tNoct", "_tMech", "_tDemo", "_tStealth", "_tSwarm"];

// Marksman campaign: lead with things a rifle can't answer, and tell
// spawnGroup to dismount the infantry WIDE (500m) instead of driving
// onto the glass.
if (_tSniper >= 0.5 && {_role isNotEqualTo "AA-capable"}) then {
    _ladder = ["AIR_CAS_DRONE", "LIGHT_ARMOR"] + (_ladder - ["AIR_CAS_DRONE", "LIGHT_ARMOR"]);
    missionNamespace setVariable ["BO_HAL_hintDismount", 500];
};
// CQB campaign: urban responses breach in force; no more lone fireteams
// feeding a building fighter.
if (_tCqb >= 0.5 && {_urban}) then {
    _ladder = ["FORTIFIED_POSITION"] + (_ladder - ["FORTIFIED_POSITION", "LGT_INFANTRY"]);
};
// Vehicle campaign: AT presence guaranteed up the ladder.
if (_tMech >= 0.5) then {
    _ladder = ["LIGHT_ARMOR"] + (_ladder - ["LIGHT_ARMOR"]);
};
// IED/demolition campaign: convoys stop short -- long dismount.
if (_tDemo >= 0.5) then {
    missionNamespace setVariable ["BO_HAL_hintDismount",
        (missionNamespace getVariable ["BO_HAL_hintDismount", 0]) max 600];
};

// Defeat-driven variety (locked #28): if HAL recently LOST in this
// area with an infantry-class package, infantry rungs rotate to the
// back -- the next wave comes as armor, air or CAS instead of more of
// the same bodies (no air vs AA-capable kit, ladder already filtered).
private _infClass = ["LGT_INFANTRY", "LGT_INFANTRY_RURAL", "MED_SQUAD", "FORTIFIED_POSITION"];
private _sbIdx = BO_HAL_setbacks findIf {
    ((_x select 0) distance2D _pos) < 800
    && {(serverTime - (_x select 1)) < 1800}
    && {(_x select 2) in _infClass}
};
if (_sbIdx != -1) then {
    private _heavy = _ladder select { !(_x in _infClass) };
    private _light = _ladder select { _x in _infClass };
    if (_heavy isNotEqualTo []) then { _ladder = _heavy + _light };
};

// Multiple fresh sightings within 300m promote one rung (doc: ">=2
// sightings within 300m" was MED_SQUAD's MVP trigger). A real cluster
// (3+) at WL>=5 brings the CAS drone overhead -- unless the cluster
// has AA in it.
private _cluster = 0;
{
    if (((_x param [1, [0,0,0]]) distance2D _pos) < 300) then { _cluster = _cluster + 1 };
} forEach (missionNamespace getVariable ["NATOknownTargets", []]);
if (_cluster >= 2 && {(_ladder select 0) isEqualTo "LGT_INFANTRY"}) then {
    _ladder = ["MED_SQUAD"] + _ladder;
};
if (_cluster >= 3 && {_wl >= 5} && {_role isNotEqualTo "AA-capable"}
    && {!("AIR_CAS_DRONE" in _ladder)}) then {
    _ladder = ["AIR_CAS_DRONE"] + _ladder;
};

// V7 jitter (one rung, 20% chance, tempo-driven).
if (BO_HAL_tempo > 0.7 && {random 1 < 0.2} && {count _ladder > 1}) then {
    // "angry": try the rung ABOVE the matched one by re-adding the
    // heaviest entry to the front twice (no-op if already heaviest).
    _ladder = [_ladder select 0] + _ladder;
};
if (BO_HAL_tempo < 0.3 && {random 1 < 0.2} && {count _ladder > 1}) then {
    _ladder deleteAt 0; // "saving budget": skip the matched rung
};

private _catalog = call BO_HAL_fnc_packageCatalog;
private _pick = [];
{
    if (_pick isEqualTo []) then {
        private _id = _x;
        private _idx = _catalog findIf { (_x select 0) isEqualTo _id };
        if (_idx >= 0) then {
            private _entry = _catalog select _idx;
            if ([_entry] call BO_HAL_fnc_packageEligible) then { _pick = _entry };
        };
    };
} forEach _ladder;

// Air-mobility mix: a third of squad responses at WL>=5 come in by
// helicopter instead of trucks (half against swarm fighters -- vertical
// envelopment beats road approaches into massed rifles). Never against
// AA-capable kit.
if (_pick isNotEqualTo [] && {(_pick select 0) isEqualTo "MED_SQUAD"}
    && {_wl >= 5} && {_role isNotEqualTo "AA-capable"}
    && {random 1 < ([0.35, 0.5] select (_tSwarm >= 0.5))}) then {
    private _aIdx = _catalog findIf { (_x select 0) isEqualTo "AIR_ASSAULT" };
    if (_aIdx >= 0 && {[_catalog select _aIdx] call BO_HAL_fnc_packageEligible}) then {
        _pick = _catalog select _aIdx;
    };
};

_pick
