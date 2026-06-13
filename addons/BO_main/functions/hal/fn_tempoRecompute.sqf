#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_tempoRecompute
 *
 * V3 (locked: posture is ONE number, not a 5-state FSM).
 * tempo 0..1 derived from peak regional heat, dwell (silentTicks) and
 * current op load. Drives the V7 over/under-commit jitter:
 *   > 0.7 "retaliating" -- may pick the next-heavier package
 *   < 0.3 "dormant"     -- may under-commit
 */

SERVER_ONLY;

private _peak = 0;
{ _peak = _peak max (_x select 1) } forEach BO_HAL_heatCache;

private _silent = server getVariable ["BO_HAL_silentTicks", 0];
private _opLoad = (count BO_HAL_activeOps) / (BO_HAL_maxConcurrentOps max 1);

BO_HAL_tempo = (0.15 + (_peak * 0.6) + (_opLoad * 0.25) - (_silent * 0.06)) max 0 min 1;
BO_HAL_tempo
