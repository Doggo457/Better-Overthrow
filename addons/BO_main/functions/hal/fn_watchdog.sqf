#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_watchdog
 *
 * AI-reliability Layers 2 + 4, 45s cadence (Layer 3 deliberately
 * deleted -- engine critique #1).
 *
 * Layer 2 -- stuck recovery, gated three ways before any teleport:
 *   1. speed < 0.5 with a MOVE order, >100m from target, for >120s
 *   2. NO player within 800m of the teleport DESTINATION with
 *      visibility on it (checkVisibility)
 *   3. NO player within 200m of the CURRENT position (audio leak)
 *
 * Layer 4 -- vehicle quirks: re-assert helo flyInHeight (LAMBS clears
 * it), reset tank forceSpeed, keep allowCrewInImmobile false.
 */

SERVER_ONLY;
if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};

private _now = serverTime;
private _players = allPlayers select { alive _x };

{
    _x params ["_opId", "_pkgId", "_grp", "_veh", "_crewGrp", "_tgt", "_origin",
               "_launch", "_status"];

    if (!isNull _veh && {alive _veh}) then {
        // Layer 4.
        if (_veh isKindOf "Helicopter") then { _veh flyInHeight 120 };
        if (_veh isKindOf "Tank" && {speed _veh < 1}) then { _veh forceSpeed -1 };
    };

    {
        private _g = _x;
        if (!isNull _g && {_status in ["transit", "extracting", "exfil", "retreating"]}) then {
            private _lead = leader _g;
            if (!isNull _lead && {alive _lead} && {vehicle _lead isEqualTo _lead}) then {
                private _stuckSince = _g getVariable ["BO_HAL_stuckSince", -1];
                private _moving = speed _lead > 0.5;
                private _hasMove = (currentCommand _lead) in ["MOVE", "GETIN"];
                private _farOut = (_lead distance2D _tgt) > 100;

                if (!_moving && _hasMove && _farOut) then {
                    if (_stuckSince < 0) then {
                        _g setVariable ["BO_HAL_stuckSince", _now, false];
                    } else {
                        if ((_now - _stuckSince) > 120) then {
                            // Teleport recovery, LOS + audio gated.
                            private _destRoad = [_lead getPos [180, _lead getDir _tgt], 300] call BIS_fnc_nearestRoad;
                            private _dest = if (!isNull _destRoad) then { getPosATL _destRoad } else { _lead getPos [150, _lead getDir _tgt] };
                            private _seen = (_players findIf {
                                private _p = _x;
                                ((_p distance2D _dest) < 800
                                    && {([objNull, "VIEW"] checkVisibility [eyePos _p, AGLToASL [_dest select 0, _dest select 1, 1.8]]) > 0.1})
                                || {(_p distance2D _lead) < 200}
                            }) != -1;
                            if (!_seen) then {
                                { _x setPosATL (_dest getPos [random 8, random 360]) } forEach (units _g select { alive _x && { vehicle _x isEqualTo _x } });
                                ["watchdog_recover", [_opId, _pkgId]] call BO_HAL_fnc_aar;
                            };
                            _g setVariable ["BO_HAL_stuckSince", -1, false];
                        };
                    };
                } else {
                    if (_stuckSince >= 0) then { _g setVariable ["BO_HAL_stuckSince", -1, false] };
                };
            };
        };
    } forEach [_grp, _crewGrp];

} forEach BO_HAL_activeOps;
