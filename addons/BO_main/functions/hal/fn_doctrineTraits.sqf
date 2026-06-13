#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_doctrineTraits
 *
 * Adaptive counter-doctrine ANALYST. Runs each full tick: decays the
 * raw counters (x0.997 -- a style change fades the old profile over
 * days of play, it never snaps), derives seven normalized 0..1 traits,
 * and caches them in missionNamespace BO_HAL_traits for the dispatch
 * layer to read for free:
 *
 *   T_SNIPER   long-range + marksman-weapon share
 *   T_CQB      sub-150m + urban share
 *   T_NOCT     darkness share
 *   T_MECH     vehicle-kill share (armor/air weighted over cars)
 *   T_DEMO     explosive kills + observed IED emplacements
 *   T_STEALTH  suppressed-weapon + lone-wolf share
 *   T_SWARM    average resistance fighters around the killer
 *
 * Shares saturate at 40% (sat(x) = min(1, share/0.4)): a playstyle
 * doesn't need to be exclusive to register as dominant. Traits only
 * activate once the network has a statistically honest sample
 * (>= 8 kills) -- no counter-doctrine off two lucky shots.
 *
 * WHERE THE TRAITS BITE (the whole point -- every threshold annotated
 * at its site): pickHotPackage ladders + dismount hint, MED/FORTIFIED
 * compositions, tick night-consistency / surge threshold / CTRG dwell
 * gate / VCOM mines, fobWatch night probes, evaluateOp retreat &
 * reinforce thresholds.
 *
 * Returns: ARRAY [sniper, cqb, noct, mech, demo, stealth, swarm]
 */

// Inlined, not SERVER_ONLY_RET([...]) -- the preprocessor splits the
// array literal on its commas and the macro errors with 7 arguments.
if (!isServer) exitWith { [0,0,0,0,0,0,0] };

private _d = server getVariable ["BO_HAL_doctrine", []];
if (_d isEqualTo [] || {(_d param [0, 0]) isNotEqualTo 1} || {(_d param [1, 0]) < 8}) exitWith {
    missionNamespace setVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]];
    [0,0,0,0,0,0,0]
};

// ---- decay (slow forget) ---------------------------------------------
for "_i" from 1 to 20 do {
    _d set [_i, (_d select _i) * 0.997];
};
{
    _x set [1, (_x select 1) * 0.997];
} forEach (_d select 21);
server setVariable ["BO_HAL_doctrine", _d];

_d params ["_v", "_k", "_r0", "_r1", "_r2", "_r3", "_r4", "_night",
           "_wSnp", "_wMG", "_wLnch", "_wExpl", "_wSupp",
           "_vCar", "_vArm", "_vAir", "_urban",
           "_allySum", "_allyN", "_lone", "_ied"];
_k = _k max 1;

private _sat = { params ["_x"]; (_x / 0.4) min 1 max 0 };

private _tSniper  = 0.55 * ([( _r3 * 0.7 + _r4) / _k] call _sat) + 0.45 * ([_wSnp / _k] call _sat);
private _tCqb     = 0.7  * ([(_r0 + 0.6 * _r1) / _k] call _sat) + 0.3 * ([_urban / _k] call _sat);
private _tNoct    = [(_night / _k) / 1.25] call _sat;   // saturates at 50% night share
private _tMech    = [(_vArm + _vAir + 0.5 * _vCar) / _k] call _sat;
private _tDemo    = [(_wExpl + _ied * 1.5) / _k] call _sat;
private _tStealth = 0.6 * ([_wSupp / _k] call _sat) + 0.4 * ([_lone / _k] call _sat);
private _tSwarm   = ((_allySum / (_allyN max 1)) / 3) min 1 max 0;

private _traits = [_tSniper, _tCqb, _tNoct, _tMech, _tDemo, _tStealth, _tSwarm];
missionNamespace setVariable ["BO_HAL_traits", _traits];
_traits
