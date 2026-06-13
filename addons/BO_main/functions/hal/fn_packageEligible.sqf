#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_packageEligible
 *
 * Locked decision #17: a package with any missing/empty required
 * OT_NATO_* var filters out BEFORE scoring -- HAL goes silent rather
 * than spawning wrong-faction content. Also applies the addendum WL
 * gates (AT>=4, AA>=6 are baked into the catalog wlMin) and budget.
 *
 * Params: 0: ARRAY catalog entry, 1: NUMBER warLevel (optional)
 * Returns: BOOL
 */

params [["_pkg", [], [[]]], ["_wl", -1, [0]]];
if (_pkg isEqualTo []) exitWith { false };
_pkg params ["_id", "_cost", "_wlMin", "_required", "_builder"];

if (_wl < 0) then {
    _wl = round (server getVariable ["BO_warLevel", 1]);
};
if (_wl < _wlMin) exitWith { false };

if ((server getVariable ["NATOresources", 0]) < _cost) exitWith { false };

private _missing = _required findIf {
    private _v = missionNamespace getVariable [_x, nil];
    isNil "_v" || { _v isEqualType [] && { _v isEqualTo [] } } || { _v isEqualType "" && { _v isEqualTo "" } }
};
if (_missing != -1) exitWith { false };

// Infantry-bearing packages additionally need the mined rifle pool.
if (_id in ["LGT_INFANTRY", "MED_SQUAD", "FORTIFIED_POSITION", "LIGHT_ARMOR", "HEAVY_ARMOR", "FACTORY_SABOTAGE", "INTERDICTION", "AIR_ASSAULT"]
    && {(missionNamespace getVariable ["BO_HAL_riflePool", []]) isEqualTo []}) exitWith { false };

true
