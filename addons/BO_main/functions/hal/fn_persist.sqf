#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_persist
 *
 * Flush HAL's save-lifetime state to the server namespace, where OT's
 * 11-step server-var walk picks it up. Called from two places:
 *   - end of every full HAL tick
 *   - fn_saveGame, immediately BEFORE the server-var walk -- so every
 *     save carries fresh strategic memory no matter where it lands in
 *     the tick interval
 * Session-lifetime state (activeOps, provocation queue, tempo) is
 * deliberately NOT persisted: ops reference live groups that cannot
 * survive serialization, and D3 zeroes the dwell counter on load.
 *
 * No broadcast (3rd arg omitted): this is server-internal bookkeeping;
 * clients never read it.
 */

SERVER_ONLY;

server setVariable ["BO_HAL_heatByRegion", BO_HAL_heatCache];
// opCounter / fobRegistry / silentTicks are written at their mutation
// sites; heat is the only tick-batched structure.
