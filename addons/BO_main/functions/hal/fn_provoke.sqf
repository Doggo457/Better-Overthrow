#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_provoke
 *
 * Provocation queue with interrupt threshold (V1, locked decision #11).
 * Events accumulate weight; when the decayed sum crosses the threshold
 * the next heartbeat (30s PFH) runs a PARTIAL tick -- hot-branch
 * dispatch only, bypassing the 20-min boundary. Coalesce-into-next-tick
 * was explicitly rejected.
 *
 * Params: 0: STRING event type, 1: ARRAY pos
 */

if (!isServer) exitWith {};
if (BO_HAL_partialPending) exitWith {}; // already scheduled

params [["_evt", "generic", [""]], ["_pos", [0,0,0], [[]]]];

private _w = switch (_evt) do {
    case "explosives":  { 0.6 };
    case "death":       { 0.5 };
    case "damaged":     { 0.45 };
    case "building":    { 0.35 };
    case "reveal":      { 0.3 };
    case "wanted":      { 0.25 };
    case "cargo":       { 0.2 };
    case "sabotage":    { 0.2 };
    case "tagged":      { 0.15 };
    default             { 0.2 };
};

BO_HAL_provocationQueue pushBack [_w, _pos, serverTime];

// Decay: drop entries older than 10 real-minutes, then sum.
private _now = serverTime;
BO_HAL_provocationQueue = BO_HAL_provocationQueue select { (_now - (_x select 2)) < 600 };
private _sum = 0;
{ _sum = _sum + (_x select 0) } forEach BO_HAL_provocationQueue;
_sum = _sum * (missionNamespace getVariable ["BO_HAL_provocationWeight", 1]);

if (_sum > (missionNamespace getVariable ["BO_HAL_provocationInterruptThreshold", 0.8])
    && {(_now - BO_HAL_lastTick) > 60}) then {
    BO_HAL_partialPending = true;
    BO_HAL_provocationQueue = [];
    ["provocation_interrupt", [_evt, round _sum]] call BO_HAL_fnc_aar;
};
