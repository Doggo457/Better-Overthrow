#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconInitClient
 *
 * Client postInit hook. Waits for OT_loaded then calls reconRebuildClient
 * so JIP / save-load both re-arm any active recon entries owned by this
 * player. Also installs a Respawn EH so death-and-respawn re-arms (the
 * client-side PFH lives on the main display so it survives the respawn,
 * but the markers and HUD ctrl can drop if the display is re-created).
 *
 * Safe to call multiple times -- rebuild is itself defensive about
 * existing local state.
 */

if (!hasInterface) exitWith {};

[] spawn {
    waitUntil { sleep 1; !isNull player && {!isNil "OT_loaded"} && {OT_loaded} };
    sleep 2;
    [] call BO_fnc_reconRebuildClient;

    // JIP race: BO_activeRecon broadcast might not have landed by the
    // time rebuild first runs. Retry once a second for 30s if the var
    // is still empty -- the rebuild itself is idempotent.
    private _uid = getPlayerUID player;
    for "_i" from 0 to 30 do {
        sleep 1;
        if (count (missionNamespace getVariable ["BO_reconClientActive", []]) > 0) exitWith {};
        private _serverActive = server getVariable ["BO_activeRecon", []];
        if ((_serverActive findIf { (_x select 0) isEqualTo _uid && {(_x select 3) > serverTime} }) >= 0) then {
            [] call BO_fnc_reconRebuildClient;
            break;
        };
    };
};

// Idempotent Respawn EH registration -- postInit may fire multiple
// times across save/loads; without a guard we'd accumulate handlers.
if (isNil "BO_reconRespawnEH") then {
    BO_reconRespawnEH = player addEventHandler ["Respawn", {
        [{ [] call BO_fnc_reconRebuildClient }, [], 1.0] call CBA_fnc_waitAndExecute;
    }];
};
