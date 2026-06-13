#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_garbageCollectorTick
 *
 * Sweep: for each dead body, check whether any player is currently
 * within proximity. If yes, refresh the body's lastNearPlayer
 * timestamp. If no AND the body has been ignored for longer than
 * the configured decay window, delete it.
 *
 * Performance: one nearEntities query per body. With ~100 corpses
 * on the map and a 30s tick, this is well under 1ms per sweep.
 *
 * Looted/empty bodies get a shorter decay window (15 min) to clear
 * battlefield clutter faster once players have stripped them.
 */

SERVER_ONLY;

private _t0 = diag_tickTime;
private _now = diag_tickTime;
private _decay = BO_corpseDecaySeconds;
private _decayLooted = 900; // 15 minutes for empty corpses
private _radius = BO_corpseDecayRadius;

private _cleaned = 0;
private _refreshed = 0;
private _exempted = 0;

{
    private _body = _x;

    // Skip player bodies and exempt corpses.
    if (isPlayer _body) then { _exempted = _exempted + 1; continue };
    if (_body getVariable ["BO_exempt", false]) then { _exempted = _exempted + 1; continue };

    // Missing death timestamp = body existed before BO was loaded,
    // or this is a unit that died in a way that bypassed the
    // EntityKilled handler. Tag it now and skip this tick.
    if (isNil { _body getVariable "BO_deathTime" }) then {
        _body setVariable ["BO_deathTime", _now, false];
        _body setVariable ["BO_lastNearPlayer", _now, false];
        continue;
    };

    // Proximity refresh: if any player is within radius, update
    // the last-seen timestamp.
    private _playerNear = (_body nearEntities ["CAManBase", _radius]) findIf { isPlayer _x } > -1;
    if (_playerNear) then {
        _body setVariable ["BO_lastNearPlayer", _now, false];
        _refreshed = _refreshed + 1;
        continue;
    };

    // No player near. Time to delete?
    private _lastNear = _body getVariable ["BO_lastNearPlayer", _now];
    private _ignoreTime = _now - _lastNear;

    // Pick the appropriate decay threshold.
    private _isLooted = (
        (primaryWeapon _body) isEqualTo "" &&
        {(handgunWeapon _body) isEqualTo ""} &&
        {(secondaryWeapon _body) isEqualTo ""} &&
        {(uniform _body) isEqualTo ""} &&
        {(vest _body) isEqualTo ""} &&
        {(backpack _body) isEqualTo ""} &&
        {magazines _body isEqualTo []} &&
        {items _body isEqualTo []}
    );
    private _threshold = if (_isLooted) then { _decayLooted } else { _decay };

    if (_ignoreTime > _threshold) then {
        deleteVehicle _body;
        _cleaned = _cleaned + 1;
    };
} forEach allDeadMen;

private _elapsed = diag_tickTime - _t0;

if (_cleaned > 0) then {
    [AUDIT_GARBAGE,
     format ["Garbage collector cleaned %1 corpses (refreshed %2, exempt %3) in %4s",
       _cleaned, _refreshed, _exempted, _elapsed],
     _cleaned,
     [_cleaned, _refreshed, _exempted, _elapsed]
    ] call BO_fnc_auditGroup;
};

["garbage", _elapsed, _cleaned] call BO_fnc_recordMetric;
