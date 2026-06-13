#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_pkg_FACTORY_SABOTAGE
 *
 * V5 greenfor reflex: a 4-man team walks onto an unwatched player
 * asset and burns it. Damage is applied by a proximity-fused charge
 * monitor (60s on-site), not instantly -- catch them in the act and
 * the asset survives. Never fires inside FOB sanctuary (the greenfor
 * view already filtered that) and the spawn-bubble check in recycleOp
 * keeps the demolition honest if a player shows up late.
 *
 * Params: 0: origin, 1: target (asset pos), 2: catalog entry
 * Returns: [grp, veh, crewGrp]
 */

SERVER_ONLY;
params ["_origin", "_tgt", "_pkg"];

private _classes = [missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""]];
private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
for "_i" from 1 to 3 do { _classes pushBack (selectRandom _pool) };
_classes = _classes select { _x isNotEqualTo "" };

([_origin, _tgt, _classes,
    missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""],
    "ground", false] call BO_HAL_fnc_spawnGroup) params ["_grp", "_veh", "_crew"];
if (isNull _grp) exitWith { [grpNull, objNull, grpNull] };

// Charge monitor: when the team has held the asset for ~60s, the
// asset takes structural damage and the team exfils (evaluateOp's
// active-timeout path recycles them with refund).
[{
    params ["_args", "_pfh"];
    _args params ["_grp", "_tgt", "_t0"];
    if (isNull _grp || {({ alive _x } count units _grp) isEqualTo 0}) exitWith {
        [_pfh] call CBA_fnc_removePerFrameHandler;
    };
    private _lead = leader _grp;
    if ((_lead distance2D _tgt) > 60) exitWith {
        _args set [2, serverTime]; // reset the fuse off-site
    };
    if ((serverTime - _t0) > 60) then {
        [_pfh] call CBA_fnc_removePerFrameHandler;
        private _assets = (server getVariable ["BO_buildFactories", []])
            + (server getVariable ["BO_buildBusinesses", []]);
        private _idx = _assets findIf { !isNull _x && {(_x distance2D _tgt) < 60} };
        if (_idx >= 0) then {
            private _asset = _assets select _idx;
            "M_Mo_82mm_AT_LG" createVehicle (getPosATL _asset);
            _asset setDamage ((damage _asset) + 0.55 min 0.9);
            ["factory_sabotaged", [getPosATL _asset]] call BO_HAL_fnc_aar;
            private _smsg = format ["HAL sabotage: player asset damaged at %1", getPosATL _asset];
            BO_LOG_INFO("hal", _smsg);
        };
        // Exfil: single move home.
        [_grp, _tgt] call BO_HAL_fnc_breakContact;
    };
}, 10, [_grp, _tgt, serverTime]] call CBA_fnc_addPerFrameHandler;

[_grp, _veh, _crew]
