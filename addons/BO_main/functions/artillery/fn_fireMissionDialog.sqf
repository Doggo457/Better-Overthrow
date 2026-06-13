#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_fireMissionDialog
 *
 * Client-local. Stage 1 of the fire-mission flow: shell-type picker.
 * Chains into BO_fnc_fireMissionPickCount (round count) ->
 * BO_fnc_fireMissionPickTarget (map click) -> remoteExec
 * BO_fnc_callFireMission.
 *
 * Uses OT_fnc_playerDecision for the picker (same pattern as
 * BO_fnc_atmDialog) so no new dialog .hpp is shipped.
 *
 * Cooldown re-check at dialog open in case another caller (or a
 * second action click in the same frame) consumed the slot between
 * the ACE-action condition tick and this dialog opening.
 *
 * Params:
 *   0: OBJECT - the mortar
 */

params [["_mortar", objNull, [objNull]]];
if (isNull _mortar) exitWith {};

private _last = _mortar getVariable ["BO_lastFireMission", 0];
private _cd   = _mortar getVariable ["BO_mortarCooldown", 300];
if ((serverTime - _last) < _cd) exitWith {
    private _msg = format ["Fire mission ready in %1s", round (_last + _cd - serverTime)];
    _msg call OT_fnc_notifyMinor;
};

// Stash the mortar reference + reset selections on missionNamespace
// because OT_fnc_playerDecision invokes click handlers from the
// global namespace (closures don't carry our locals across the UI
// boundary).
missionNamespace setVariable ["BO_fmMortar", _mortar];
missionNamespace setVariable ["BO_fmShellType", ""];
missionNamespace setVariable ["BO_fmCount", 0];

private _opts = [];
_opts pushBack "<t align='center' size='1.1'>Fire Mission: Select Shell</t><br/><t align='center' size='0.7'>HE $500/rd  |  Smoke $150/rd  |  Illum $100/rd</t>";
_opts pushBack ["HE (anti-personnel)",  { missionNamespace setVariable ["BO_fmShellType", "HE"];    [] call BO_fnc_fireMissionPickCount }];
_opts pushBack ["Smoke (concealment)",  { missionNamespace setVariable ["BO_fmShellType", "SMOKE"]; [] call BO_fnc_fireMissionPickCount }];
_opts pushBack ["Illumination (night)", { missionNamespace setVariable ["BO_fmShellType", "ILLUM"]; [] call BO_fnc_fireMissionPickCount }];
_opts pushBack ["Cancel", {}];
_opts call OT_fnc_playerDecision;
