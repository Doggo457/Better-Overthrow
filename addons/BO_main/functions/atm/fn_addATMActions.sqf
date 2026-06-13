#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_addATMActions
 *
 * Per-client postInit setup for banking. Single layer now:
 *
 *   ACE Main Action "Use ATM" on any shopkeeper NPC. OT tags every
 *   shopkeeper / gun dealer / car dealer / faction rep with the
 *   namespace variable `shopcheck=true`. We register the action
 *   against the underlying civilian class (C_man_w_worker_F) and
 *   gate visibility on that variable so it only appears on actual
 *   shop NPCs -- not on every random civilian in town.
 *
 *   Using the shopkeeper as the "ATM" object means the existing
 *   isNATOControlledATM logic (which finds nearest town to the
 *   object) automatically picks up the shop's town and applies the
 *   appropriate fee.
 *
 * Remote banking via ACE Self Interact was removed on user request --
 * banking now requires physical interaction with a shopkeeper.
 *
 * Idempotent via BO_atmActionsInstalled.
 */

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["BO_atmActionsInstalled", false]) exitWith {};
missionNamespace setVariable ["BO_atmActionsInstalled", true];

[] spawn {
    waitUntil { sleep 0.5; !isNull player };

    private _shopAction = [
        "BO_useATMShop",
        "Use ATM",
        "",
        { [_target] call BO_fnc_atmDialog },
        { _target getVariable ["shopcheck", false] }
    ] call ace_interact_menu_fnc_createAction;

    [
        "C_man_w_worker_F", 0, ["ACE_MainActions"], _shopAction
    ] call ace_interact_menu_fnc_addActionToClass;

    BO_LOG_INFO("atm", "Banking ready: shopkeeper main-action registered (no remote ATM)");
};
