#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_warLevelBump
 *
 * Antistasi-style aggression dial, DECOUPLED from NATOresources
 * (locked decision #27 revision): `server var "BO_warLevel"` (0..10,
 * float internally, HUD shows rounded) measures how angry NATO is,
 * independent of what it can afford. Escalates from player actions
 * (sightings, NATO losses, tower captures), decays slowly while the
 * island is quiet (fn_tick). Resources remain purely the spending
 * ledger.
 *
 * Server-only; clamped; broadcast (HUD + Options label read it);
 * auto-persisted by the server-var walk.
 *
 * Params: 0: NUMBER delta, 1: STRING reason (log)
 * Returns: NUMBER new war level
 */

SERVER_ONLY_RET(0);
params [["_delta", 0, [0]], ["_reason", "", [""]]];

private _old = server getVariable ["BO_warLevel", 1];
private _new = ((_old + _delta) max 0) min 10;
server setVariable ["BO_warLevel", _new, true];

// Log only when the visible (rounded) dial actually moves.
if (round _old isNotEqualTo round _new) then {
    private _msg = format ["War Level %1 -> %2 (%3)", round _old, round _new, _reason];
    BO_LOG_INFO("hal", _msg);
    ["warlevel", [round _new, _reason]] call BO_HAL_fnc_aar;
};

_new
