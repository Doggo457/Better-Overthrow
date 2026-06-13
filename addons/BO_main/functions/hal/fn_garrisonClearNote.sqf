#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_garrisonClearNote
 *
 * Recapture path (hooked into BO_fnc_clearReconState): NATO retook the
 * base and rolls a fresh garrison, so the old target/deficit record is
 * stale. Drop it; the next despawn snapshot re-seeds it at the new
 * garrison's strength.
 *
 * Params: 0: STRING base name
 */

SERVER_ONLY;
params [["_base", "", [""]]];
if (_base isEqualTo "") exitWith {};

private _reg = server getVariable ["BO_HAL_garrisonTargets", []];
private _idx = _reg findIf { (_x select 0) isEqualTo _base };
if (_idx >= 0) then {
    _reg deleteAt _idx;
    server setVariable ["BO_HAL_garrisonTargets", _reg];
};
