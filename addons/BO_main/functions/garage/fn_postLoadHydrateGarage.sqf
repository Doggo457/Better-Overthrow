#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_postLoadHydrateGarage
 *
 * Walk live vehicles after a save/load round-trip and re-install the
 * insurance Killed EH on anything still flagged BO_insured. Killed
 * event handlers don't survive serialization, so without this every
 * insured vehicle would silently stop paying out after a reload.
 *
 * Idempotent -- BO_fnc_installInsuranceKilledEH skips vehicles whose
 * BO_insuranceEHInstalled flag is already set.
 *
 * Called from BO_fnc_postLoadHydrate at the tail end of its run.
 */

SERVER_ONLY;

private _count = 0;
{
    if (alive _x && {_x getVariable ["BO_insured", false]}) then {
        [_x] call BO_fnc_installInsuranceKilledEH;
        _count = _count + 1;
    };
} forEach vehicles;

private _msg = format ["Garage rehydrate: re-installed insurance EH on %1 vehicles", _count];
BO_LOG_INFO("garage", _msg);
