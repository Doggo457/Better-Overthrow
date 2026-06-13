#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_greenforBranch
 *
 * Economy retaliation when the player is invisible (M6 + V5).
 * Preference order:
 *   1. FACTORY_SABOTAGE on a known asset outside FOB sanctuary,
 *      only when the player has been away 2+ ticks (locked #9 spirit).
 *   2. GREENFOR_HIT: delegate a counter-attack on the highest-
 *      stability resistance town (OT's own machinery does the rest).
 *
 * Returns: BOOL launched
 */

SERVER_ONLY;

if (BO_HAL_disableGreenforTargeting) exitWith { false };

private _catalog = call BO_HAL_fnc_packageCatalog;
private _silent = server getVariable ["BO_HAL_silentTicks", 0];

// ---- supply-line interdiction (Phase 3 "cut supply lines") ----------
// Preferred when a delivery is actually rolling: hitting logistics in
// motion beats burning static assets.
private _interdicted = false;
if (random 1 < 0.5) then {
    _interdicted = call BO_HAL_fnc_interdictLogistics;
};
if (_interdicted) exitWith { true };

// ---- factory / business sabotage ------------------------------------
private _launched = false;
if (_silent >= 2) then {
    private _view = call BO_HAL_fnc_rebuildGreenforView;
    if (_view isNotEqualTo []) then {
        private _idx = _catalog findIf { (_x select 0) isEqualTo "FACTORY_SABOTAGE" };
        if (_idx >= 0) then {
            private _pkg = _catalog select _idx;
            if ([_pkg] call BO_HAL_fnc_packageEligible) then {
                private _asset = selectRandom _view;
                _launched = ([_pkg, _asset select 1, "greenfor"] call BO_HAL_fnc_launchPackage) >= 0;
            };
        };
    };
};
if (_launched) exitWith { true };

// ---- counter-town ----------------------------------------------------
private _idx = _catalog findIf { (_x select 0) isEqualTo "GREENFOR_HIT" };
if (_idx < 0) exitWith { false };
private _pkg = _catalog select _idx;
if (!([_pkg] call BO_HAL_fnc_packageEligible)) exitWith { false };

// Highest-stability resistance town (the one hurting NATO most).
private _abandoned = server getVariable ["NATOabandoned", []];
private _best = ["", -1];
{
    if (_x in _abandoned) then {
        private _stab = server getVariable [format ["stability%1", _x], 0];
        if (_stab > (_best select 1)) then { _best = [_x, _stab] };
    };
} forEach (missionNamespace getVariable ["OT_allTowns", []]);

if ((_best select 0) isEqualTo "") exitWith { false };
private _tpos = server getVariable [(_best select 0), []];
if (_tpos isEqualTo []) exitWith { false };

// Stash the town name for the delegated builder.
BO_HAL_greenforTown = _best select 0;
private _r = [_pkg, _tpos, "greenfor"] call BO_HAL_fnc_launchPackage;
_r >= 0
