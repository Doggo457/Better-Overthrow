#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_clearReconState
 *
 * Wipe a base's saved garrison layout and reconned flag. Called when
 * NATO takes a town/objective back -- the snapshot from before the
 * recapture is no longer accurate (NATO has reinforced, repositioned,
 * possibly changed unit types), so we let the next spawn roll fresh
 * positions with NATO's current resource budget.
 *
 * Hooked into all four NATO recapture callbacks:
 *   - fn_NATOCounterObjective (objective counter-attack success)
 *   - fn_NATOCounterTown      (town counter-attack success)
 *   - fn_NATOResponseObjective (objective response success)
 *   - fn_NATOResponseTown     (town response success)
 *
 * No-op if there's no state to clear. Safe to call repeatedly.
 *
 * Params:
 *   0: STRING - base / town / objective name
 */

SERVER_ONLY;

params [["_baseName", "", [""]]];
if (_baseName isEqualTo "") exitWith {};

private _hadLayout = !((server getVariable [format ["BO_reconLayout_%1", _baseName], []]) isEqualTo []);
private _wasReconned = server getVariable [format ["BO_reconned_%1", _baseName], false];

server setVariable [format ["BO_reconLayout_%1", _baseName], nil, true];
server setVariable [format ["BO_reconned_%1", _baseName], nil, true];

// BO HAL hook: recaptured base rolls a fresh garrison -- drop the
// stale reinforcement target; the next snapshot re-seeds it.
if (!isNil "BO_HAL_fnc_garrisonClearNote") then {
    [_baseName] call BO_HAL_fnc_garrisonClearNote;
};

if (_hadLayout || _wasReconned) then {
    private _msg = format ["Cleared recon state for %1 (NATO recaptured)", _baseName];
    BO_LOG_INFO("recon", _msg);
    [AUDIT_ADMIN, _msg, [_baseName], "", ""] call BO_fnc_auditServer;
};
