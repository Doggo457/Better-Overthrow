#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_ingestSighting
 *
 * Universal sighting ingress (M2 + V1). Writes the extended 7-slot
 * schema into the EXISTING NATOknownTargets buffer (locked decision #2:
 * no parallel sighting system) and feeds the provocation queue + heat.
 *
 * Slot 5 MUST be engine `time`: OT writers (fn_NATOreportThreat:18,45,
 * fn_NATOcheckObjectives:64) use `time` and the sweeper at
 * fn_factionNATO deletes entries where (time - slot5) > 800. Writing
 * serverTime here kills entries within one sweep.
 *
 * Wanted-only (locked decision #1): `captive _unit` true => invisible.
 *
 * Params:
 *   0: OBJECT unit sighted (objNull allowed for anonymous events)
 *   1: ARRAY  pos override (default: unit pos)
 *   2: STRING event type for provocation weighting (default "generic")
 *   3: ARRAY  pre-classified kit (default: classify here)
 */

if (!isServer) exitWith { _this remoteExec ["BO_HAL_fnc_ingestSighting", 2, false] };
if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};

params [
    ["_unit", objNull, [objNull]],
    ["_pos", [], [[]]],
    ["_evt", "generic", [""]],
    ["_kit", [], [[]]],
    ["_quiet", false, [false]]  // ISR refresh: upsert only, no provocation
];

// Anonymous world event (e.g. building damaged): heat + provocation only.
if (isNull _unit) exitWith {
    if (_pos isNotEqualTo []) then {
        [_pos, 0.08] call BO_HAL_fnc_heatBump;
        [_evt, _pos] call BO_HAL_fnc_provoke;
    };
};

if (!alive _unit) exitWith {};
// Wanted-only filter. Side filter: HAL hunts the resistance, not CRIM AI.
if (_unit isKindOf "Man" && {captive _unit}) exitWith {};
if (side group _unit isNotEqualTo independent && {!isPlayer _unit}) exitWith {};

if (_pos isEqualTo []) then { _pos = getPosATL _unit };

private _observedKit = if (_kit isNotEqualTo []) then { _kit } else {
    [_unit] call BO_HAL_fnc_classifyObservedKit
};
private _role = _observedKit param [3, "infantry"];
private _priority = [_role] call BO_HAL_fnc_priorityFromKit;
private _type = typeOf _unit;

// Upsert into NATOknownTargets (7-slot extended schema, slot 5 = time).
if (isNil "NATOknownTargets") then { NATOknownTargets = [] };
private _entry = [_type, _pos, _priority, _unit, false, time, _observedKit];
private _idx = NATOknownTargets findIf { (_x param [3, objNull]) isEqualTo _unit };
if (_idx >= 0) then {
    NATOknownTargets set [_idx, _entry];
} else {
    NATOknownTargets pushBack _entry;
};

// Freshest-sighting memory for discovery ellipses + CTRG hunts.
// Heading: unit's current movement direction.
BO_HAL_lastKnown = [_pos, time, getDir _unit];

// Heat + provocation + war-level escalation. Quiet (drone ISR)
// refreshes keep the target buffer warm without feeding either.
if (_quiet) then {
    [_pos, 0.01] call BO_HAL_fnc_heatBump;
} else {
    [_pos, 0.05 + 0.03 * _priority] call BO_HAL_fnc_heatBump;
    [_evt, _pos] call BO_HAL_fnc_provoke;
    private _wlDelta = switch (_evt) do {
        case "explosives": { 0.10 };
        case "death":      { 0.08 };
        case "damaged":    { 0.05 };
        case "building":   { 0.05 };
        default            { 0.02 };
    };
    [_wlDelta, _evt] call BO_HAL_fnc_warLevelBump;
};

// Preserve legacy vehicle-reported behavior (mirrors OT wantedLoop).
if (vehicle _unit isNotEqualTo _unit) then {
    (vehicle _unit) call OT_fnc_NATOreportThreat;
};
