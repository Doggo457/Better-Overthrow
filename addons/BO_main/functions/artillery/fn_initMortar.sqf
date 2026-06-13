#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initMortar
 *
 * Called when a Mortar Position buildable is placed AND when a saved
 * mortar is rehydrated by loadGame (slot-6 OT_init replay). Mirrors
 * fn_initFactory's shape:
 *   - per-object state defaults via nil-checks so a loaded mortar's
 *     restored cooldown / owner vars survive the rehydrate path
 *   - registered into BO_buildMortars via BO_fnc_registerMortar
 *   - OT_forceSaveUnowned flag so the unowned-filter doesn't drop
 *     player-placed mortars from persistence
 *
 * Per-mortar cooldown is cached at placement time (BO_mortarCooldown)
 * so changing the mission param mid-game only affects new placements.
 *
 * Called via `[_pos, _veh] spawn BO_fnc_initMortar` from
 * fn_initBuilding.
 *
 * Server-only. Audits at AUDIT_ARTILLERY.
 *
 * Params:
 *   0: ARRAY  - placement position
 *   1: OBJECT - the mortar (B_Mortar_01_F)
 */

if (!isServer) exitWith {};

params [
    ["_pos", [0,0,0], [[]]],
    ["_mortar", objNull, [objNull]]
];
if (isNull _mortar) exitWith {};

// Per-object state defaults. Only set if nil so a loaded mortar's
// restored vars (slot 12 in fn_loadGame) survive this rehydrate path.
if (isNil { _mortar getVariable "BO_lastFireMission" }) then {
    _mortar setVariable ["BO_lastFireMission", 0, true];
};

if (isNil { _mortar getVariable "BO_mortarOwnerUID" }) then {
    // Placer attribution. fn_build calls OT_fnc_setOwner BEFORE the
    // init hook fires, so the canonical placer UID is already on the
    // "owner" object var. Fall back to nearby players (covers paths
    // that bypass setOwner) then to the first general for unattended
    // map-baked entries.
    private _placer = _mortar getVariable ["owner", ""];
    if (_placer isEqualTo "") then {
        private _candidates = (_pos nearEntities ["CAManBase", 20]) select { isPlayer _x };
        if (count _candidates > 0) then { _placer = getPlayerUID (_candidates select 0) };
    };
    if (_placer isEqualTo "") then {
        private _gens = server getVariable ["generals", []];
        if (count _gens > 0) then { _placer = _gens select 0 };
    };
    _mortar setVariable ["BO_mortarOwnerUID", _placer, true];
};

if (isNil { _mortar getVariable "BO_mortarCooldown" }) then {
    private _cd = missionNamespace getVariable ["BO_artilleryCooldownSec", 300];
    _mortar setVariable ["BO_mortarCooldown", _cd, true];
};

// Mark for save even if unowned -- player-placed mortars don't get
// a tidy OT owner via this pipeline, and the save filter would drop
// them without this flag. Slot 12 in fn_saveGame carries the actual
// per-mortar state payload.
_mortar setVariable ["OT_forceSaveUnowned", true, true];

[_mortar] call BO_fnc_registerMortar;

[AUDIT_ARTILLERY,
    "Mortar placed/rehydrated",
    [getPosATL _mortar, _mortar getVariable ["BO_mortarOwnerUID", ""]],
    "",
    ""
] call BO_fnc_auditServer;

private _msg = format ["Mortar position operational at %1", mapGridPosition _mortar];
_msg remoteExec ["OT_fnc_notifyGood", 0, false];
