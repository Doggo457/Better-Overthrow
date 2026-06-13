#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventLoop
 *
 * Server-only. Installs the per-frame handler that drives daytime
 * civilian saboteur ("informant") events. Every ~15 in-game minutes
 * we wake, then call BO_fnc_civilianEventTick which picks 1..N
 * eligible high-stability towns and seeds an informant in each.
 *
 * Idempotent: re-calling skips if BO_civilianEventLoopHandle exists.
 * Disabled via mission param BO_civilianEventsEnabled.
 */

if (!isServer) exitWith {};

if (!isNil "BO_civilianEventLoopHandle") exitWith {
    BO_LOG_DEBUG("civilian","civilianEventLoop already installed");
};

if (!(missionNamespace getVariable ["BO_civilianEventsEnabled", true])) exitWith {
    BO_LOG_INFO("civilian","civilianEventLoop disabled via mission param");
};

// 15 in-game minutes / time acceleration. OT_timeMultiplier may be nil
// on some campaigns; default to 1.0 so the math doesn't divide-by-zero.
private _accel = if (isNil "OT_timeMultiplier") then { 1.0 } else { OT_timeMultiplier };
if (_accel <= 0) then { _accel = 1.0 };
private _interval = (15 * 60) / _accel;

BO_civilianEventLoopHandle = [{
    if (!(missionNamespace getVariable ["BO_civilianEventsEnabled", true])) exitWith {};
    [] call BO_fnc_civilianEventTick;
}, _interval, []] call CBA_fnc_addPerFrameHandler;

private _msg = format ["civilianEventLoop installed (interval=%1s)", _interval];
BO_LOG_INFO("civilian", _msg);
