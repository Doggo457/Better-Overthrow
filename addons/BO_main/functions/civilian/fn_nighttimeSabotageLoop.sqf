#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_nighttimeSabotageLoop
 *
 * Server-only. Installs the PFH that fires nighttime sabotage at
 * NATO bases during in-game hours 22..05. Once-per-night gate by
 * default; "Multiple" frequency unlocks up to 3 events per game-day.
 *
 * Tick interval is 10 real-minutes -- cheap, body short-circuits
 * unless the in-game hour is in the 22..05 window.
 *
 * Idempotent: re-call skips if handle exists. Disabled via
 * mission param BO_nighttimeSabotageEnabled.
 */

if (!isServer) exitWith {};

if (!isNil "BO_nighttimeSabotageLoopHandle") exitWith {
    BO_LOG_DEBUG("civilian","nighttimeSabotageLoop already installed");
};

if (!(missionNamespace getVariable ["BO_nighttimeSabotageEnabled", true])) exitWith {
    BO_LOG_INFO("civilian","nighttimeSabotageLoop disabled via mission param");
};

private _interval = 600;

BO_nighttimeSabotageLoopHandle = [{
    if (!(missionNamespace getVariable ["BO_nighttimeSabotageEnabled", true])) exitWith {};
    private _hour = date select 3;
    if (!(_hour >= 22 || _hour < 5)) exitWith {};

    private _freq = missionNamespace getVariable ["BO_nighttimeSabotageFrequency", 1];
    if (_freq isEqualTo 0) exitWith {};

    // Include year so the same calendar day in two different years
    // doesn't collide on the "already fired today" gate.
    private _dayKey = ((date select 0) * 400) + ((date select 1) * 32) + (date select 2);
    private _last = missionNamespace getVariable ["BO_lastSabotageDay", -1];

    if (_freq isEqualTo 1 && {_last isEqualTo _dayKey}) exitWith {};

    if (_freq isEqualTo 2) then {
        private _countKey = format ["BO_sabotageCount_%1", _dayKey];
        private _countToday = missionNamespace getVariable [_countKey, 0];
        if (_countToday >= 3) exitWith {};
    };

    [] call BO_fnc_pickAndRunSabotage;

    missionNamespace setVariable ["BO_lastSabotageDay", _dayKey];
    server setVariable ["BO_lastSabotageDay", _dayKey, true];

    if (_freq isEqualTo 2) then {
        private _k = format ["BO_sabotageCount_%1", _dayKey];
        private _cur = (missionNamespace getVariable [_k, 0]) + 1;
        missionNamespace setVariable [_k, _cur];
    };
}, _interval, []] call CBA_fnc_addPerFrameHandler;

private _msg = format ["nighttimeSabotageLoop installed (interval=%1s)", _interval];
BO_LOG_INFO("civilian", _msg);
