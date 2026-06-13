#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initArtillery
 *
 * One-shot server bootstrap called from fn_postInit after the
 * businessLoop install. Reads the artillery / CAS mission params,
 * builds the ammo + CAS-loadout lookup hashmaps, and prunes any
 * dead/null entries that survived the save -> load round trip in
 * the BO_buildMortars / BO_buildCASHelipads registries.
 *
 * Artillery and CAS are CALL-DRIVEN (player clicks an action ->
 * server schedules a one-shot CBA_fnc_waitAndExecute). There is
 * deliberately no per-frame PFH loop for them; this init exists
 * solely to seed missionNamespace constants and clean the
 * registries.
 *
 * Server-only. Audits at AUDIT_ARTILLERY.
 */

SERVER_ONLY;

// Mission param: cooldown (minutes) between consecutive fire missions
// from the same mortar. Cached onto each mortar at placement so
// adjusting the param mid-game only affects new placements.
BO_artilleryCooldownSec = (["bo_artillery_cooldown_min", 5] call BIS_fnc_getParamValue) * 60;
if (BO_artilleryCooldownSec <= 0) then { BO_artilleryCooldownSec = 300 };

// Mission param: standing penalty applied per civilian killed by a
// player-tagged fire mission shell or CAS heli. Read at kill time
// in BO_fnc_deathHandlerServer so changes take effect immediately.
BO_artilleryCivPenalty = (["bo_artillery_civilian_penalty", -5] call BIS_fnc_getParamValue);

// Mission param: cooldown (minutes) between consecutive CAS dispatches
// from the same helipad.
BO_casCooldownSec = (["bo_cas_cooldown_min", 20] call BIS_fnc_getParamValue) * 60;
if (BO_casCooldownSec <= 0) then { BO_casCooldownSec = 1200 };

// ---------------------------------------------------------------------
// Mortar shell table. Keys are shell-type codes used in the dialog
// flow; values are [_ammoClass, _pricePerRound].
// Verified against base-game B_Mortar_01_F magazines: Sh_82mm_AMOS
// (HE), Smoke_82mm_AMOS_White (smoke), F_82mm_AMOS (illum).
// ---------------------------------------------------------------------
BO_artilleryAmmo = createHashMap;
BO_artilleryAmmo set ["HE",    ["Sh_82mm_AMOS",          500]];
BO_artilleryAmmo set ["SMOKE", ["Smoke_82mm_AMOS_White", 150]];
BO_artilleryAmmo set ["ILLUM", ["F_82mm_AMOS",           100]];

// ---------------------------------------------------------------------
// CAS loadout table. Keys are heli classnames; values are per-call
// cost. Player picks whichever supported heli is parked; cost is
// looked up by typeOf.
//
// BO multi-nation: classes derive from the per-map OT_NATO_Vehicles_
// AirSupport / AirSupport_Small arrays so that swapping
// OT_faction_NATO to RHS / CUP / etc still produces a working CAS
// gate. Without this, the typeOf gate in fn_addArtilleryActions
// would reject every non-vanilla-BLU_F heli class and the CAS action
// would be permanently disabled. Light tier defaults to $8k, heavy
// to $25k. Anything else the faction defines as AirSupport
// inherits the heavy cost.
// ---------------------------------------------------------------------
BO_casLoadouts = createHashMap;
private _lightSupport = if (!isNil "OT_NATO_Vehicles_AirSupport_Small") then { OT_NATO_Vehicles_AirSupport_Small } else { [] };
private _heavySupport = if (!isNil "OT_NATO_Vehicles_AirSupport")       then { OT_NATO_Vehicles_AirSupport }       else { [] };
{ BO_casLoadouts set [_x, 8000]  } forEach _lightSupport;
{ BO_casLoadouts set [_x, 25000] } forEach _heavySupport;
// Defensive: if the faction defines neither, fall back to vanilla
// BLU_F so CAS isn't dead on a misconfigured map. The fallback path
// SHOULD never fire for shipped maps -- all four populate both.
if ((count BO_casLoadouts) isEqualTo 0) then {
    BO_casLoadouts set ["B_Heli_Light_01_armed_F",  8000];
    BO_casLoadouts set ["B_Heli_Attack_01_F",      25000];
    BO_LOG_WARN("artillery", "CAS loadout fell back to vanilla BLU_F -- OT_NATO_Vehicles_AirSupport(_Small) empty");
};

// Prune mortars/helipads that didn't survive load (dead/null).
private _mortars = (server getVariable ["BO_buildMortars", []]) select { !isNull _x && {alive _x} };
server setVariable ["BO_buildMortars", _mortars, true];
private _pads = (server getVariable ["BO_buildCASHelipads", []]) select { !isNull _x && {alive _x} };
server setVariable ["BO_buildCASHelipads", _pads, true];

private _msg = format ["artillery init: %1 mortars, %2 CAS pads, cooldown=%3s, civPenalty=%4, casCooldown=%5s",
    count _mortars, count _pads, BO_artilleryCooldownSec, BO_artilleryCivPenalty, BO_casCooldownSec];
BO_LOG_INFO("artillery", _msg);

[AUDIT_ARTILLERY,
    "Artillery subsystem online",
    [count _mortars, count _pads, BO_artilleryCooldownSec, BO_artilleryCivPenalty, BO_casCooldownSec],
    "",
    ""
] call BO_fnc_auditServer;
