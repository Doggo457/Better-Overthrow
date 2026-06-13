#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_commanderAppoint
 *
 * Pick a random NATO-held base (objective or airport, not abandoned)
 * and seat the HAL Regional Commander there. The physical detail
 * spawns lazily via the presence PFH; this only sets state.
 *
 * Params: 0: BOOL announce (replacement gets an intel whisper;
 *         the campaign-start seat is silent)
 * Returns: BOOL appointed
 */

SERVER_ONLY_RET(false);
params [["_announce", false, [false]]];

private _abandoned = server getVariable ["NATOabandoned", []];
private _cands = ((missionNamespace getVariable ["OT_objectiveData", []])
    + (missionNamespace getVariable ["OT_airportData", []])) select {
    !((_x select 1) in _abandoned)
};
if (_cands isEqualTo []) exitWith {
    // NATO holds nothing -- no seat to fill; the replacement clock
    // retries via commanderInit's PFH after the reclaim assault.
    server setVariable ["BO_HAL_cmdRespawnAt", serverTime + 600];
    false
};

private _pick = selectRandom _cands;
_pick params ["_pos", "_name"];

server setVariable ["BO_HAL_cmdBase", _name, true];
server setVariable ["BO_HAL_cmdAlive", true, true];
missionNamespace setVariable ["BO_HAL_cmdPos", +_pos];

if (_announce) then {
    "NATO has appointed a new regional commander -- the network is hunting his location"
        remoteExec ["OT_fnc_notifyMinor", 0, false];
};

["commander_appointed", [_name]] call BO_HAL_fnc_aar;
private _msg = format ["HAL Commander seated at %1", _name];
BO_LOG_INFO("hal", _msg);
true
