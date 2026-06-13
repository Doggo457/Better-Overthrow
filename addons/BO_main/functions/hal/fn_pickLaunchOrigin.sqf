#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pickLaunchOrigin
 *
 * Where a package physically departs from. RULE (user-locked): NATO
 * units only ever spawn AT NATO BASES -- HQ, objectives, airports --
 * whether the base is currently loaded (player inside the spawn
 * bubble) or virtualized. No field spawns, no off-screen bearing
 * fallback: if NATO holds no viable base, the launch ABORTS (caller
 * refunds the budget).
 *
 * Selection order:
 *   1. Unwatched bases (no player within OT_spawnDistance), nearest
 *      to the target first -- forces appear off-screen and drive in.
 *   2. If every base is watched: nearest watched base anyway --
 *      reinforcements visibly mustering at a loaded base beats no
 *      response at all (loaded bases are explicitly allowed).
 *
 * Params: 0: ARRAY target pos, 1: BOOL wantAir (default false)
 * Returns: ARRAY pos, or [] when NATO has no base to launch from.
 */

SERVER_ONLY;
params [["_tgt", [0,0,0], [[]]], ["_wantAir", false, [false]]];

// OT's own attack-vector model already enumerates base-class origins
// (objectiveData + airportData, abandoned filtered, sorted by
// distance); air vectors add the NATO helipads.
([_tgt] call OT_fnc_NATOGetAttackVectors) params [["_ground", []], ["_air", []]];
private _pool = [_ground, _air] select _wantAir;
if (_pool isEqualTo [] && {_wantAir}) then { _pool = _ground };
if (_pool isEqualTo [] && {!_wantAir}) then { _pool = _air };

private _players = allPlayers select { alive _x };

// Pass 1: unwatched bases.
private _origin = [];
{
    _x params ["_obpos", "_name"];
    if (_origin isEqualTo []) then {
        if ((_obpos distance2D _tgt) > 800
            && {(_players findIf { (_x distance2D _obpos) < OT_spawnDistance }) == -1}) then {
            _origin = +_obpos;
        };
    };
} forEach _pool;

// Pass 2: watched (loaded) bases allowed -- still bases only.
if (_origin isEqualTo []) then {
    {
        _x params ["_obpos", "_name"];
        if (_origin isEqualTo [] && {(_obpos distance2D _tgt) > 800}) then {
            _origin = +_obpos;
        };
    } forEach _pool;
};

if (_origin isEqualTo []) then {
    BO_LOG_INFO("hal", "pickLaunchOrigin: no NATO base available -- launch will abort");
};

_origin
