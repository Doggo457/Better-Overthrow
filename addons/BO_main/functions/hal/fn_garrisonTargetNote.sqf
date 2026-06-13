#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_garrisonTargetNote
 *
 * Bookkeeping feed for garrison reinforcements (PLAN Phase 3). Hooked
 * into BO_fnc_reconSnapshot: every time a base's layout is snapshotted
 * at despawn, note its CURRENT strength and maintain its TARGET
 * strength (the high-water mark = the as-generated garrison; attrition
 * never lowers the bar, recapture resets it via garrison clear).
 *
 * Registry (server var BO_HAL_garrisonTargets, auto-persisted):
 *   [baseName, target, pos, deficitTicks, lastReinforceServerTime]
 *
 * Strength counts men: INF entries + crew seats inside VEH entries.
 *
 * Params: 0: STRING base name, 1: ARRAY snapshot entries
 */

SERVER_ONLY;
params [["_base", "", [""]], ["_entries", [], [[]]]];
if (_base isEqualTo "" || {_entries isEqualTo []}) exitWith {};
if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};

private _strength = 0;
private _pos = [];
{
    _x params ["_type", "_epos", "_vd", "_vu", "_payload", "_kind"];
    if (_pos isEqualTo []) then { _pos = +_epos };
    if (_kind isEqualTo "INF") then {
        _strength = _strength + 1;
    } else {
        _strength = _strength + count _payload;
    };
} forEach _entries;
if (_pos isEqualTo []) exitWith {};
_pos set [2, 0];

private _reg = server getVariable ["BO_HAL_garrisonTargets", []];
private _idx = _reg findIf { (_x select 0) isEqualTo _base };
if (_idx >= 0) then {
    private _e = _reg select _idx;
    _e set [1, (_e select 1) max _strength];
    _e set [2, _pos];
} else {
    _reg pushBack [_base, _strength max 4, _pos, 0, 0];
};
server setVariable ["BO_HAL_garrisonTargets", _reg];
