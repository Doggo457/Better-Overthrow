#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_garrisonReinforce
 *
 * The Phase-3 marquee: depleted garrisons EVOLVE instead of decaying.
 * Runs on every full tick (doctrine, not aggression -- no consistency
 * roll). Per registered base (fn_garrisonTargetNote):
 *
 *   current strength = snapshot men (despawned base) or live tagged
 *   units (spawned base).
 *
 *   TRIGGER (all must hold, per PLAN Phase 3):
 *     - current < 70% of target
 *     - deficit persisted across 2 consecutive full ticks (no instant
 *       reinforce mid-firefight; the convoy has to actually depart)
 *     - no resistance fighter within 500m of the base (a fight is not
 *       a resupply window)
 *     - no convoy already inbound for this base; 60-min per-base
 *       cooldown between convoys
 *     - NATOresources covers cost (25/man + 60/vehicle) plus a 150
 *       reserve -- a starved NATO stops rebuilding (player-visible
 *       budget pressure, locked decision #3's single ledger)
 *
 *   CONVOY: TL + riflemen (deficit, capped 8) in a faction transport,
 *   spawned at a NATO attack vector, driving in. Fully interceptable;
 *   wiped convoy = budget lost, no refund. Arrival handling lives in
 *   fn_evaluateOp (live join vs snapshot serialize).
 */

SERVER_ONLY;
if (!(missionNamespace getVariable ["BO_HAL_garrisonReinforceOn", true])) exitWith {};

private _reg = server getVariable ["BO_HAL_garrisonTargets", []];
if (_reg isEqualTo []) exitWith {};

private _now = serverTime;
private _res = server getVariable ["NATOresources", 0];
private _abandoned = server getVariable ["NATOabandoned", []];
private _dirty = false;

{
    _x params ["_base", "_target", "_pos", "_deficitTicks", "_lastReinforce"];
    private _entry = _x;

    // serverTime resets each session: a persisted lastReinforce from a
    // longer prior session reads as "the future" and would freeze the
    // per-base cooldown for hours. Clamp stale stamps (same class of
    // bug as the artillery cooldown fix in fn_loadGame).
    if (_lastReinforce > _now) then {
        _lastReinforce = 0;
        _entry set [4, 0];
        _dirty = true;
    };

    // Base lost to the resistance since noting? Stop feeding it.
    if (_base in _abandoned) then {
        _entry set [3, 0];
    } else {
        // ---- current strength ------------------------------------------
        private _snap = server getVariable [format ["BO_reconLayout_%1", _base], []];
        private _current = 0;
        if (_snap isNotEqualTo []) then {
            {
                _current = _current + ([1, count (_x param [4, []])] select ((_x param [5, "INF"]) isEqualTo "VEH"));
            } forEach _snap;
        } else {
            // Spawned (or never yet despawned): count live tagged men.
            _current = {
                alive _x && {(_x getVariable ["garrison", ""]) isEqualTo _base}
            } count allUnits;
        };

        // ---- garrison relief (PLAN Phase 3 "garrison breakout") ---------
        // A base under sustained siege (resistance inside 500m across 2+
        // consecutive ticks) gets a relief column instead of waiting to
        // bleed out: LIGHT_ARMOR when WL/vars allow, MED_SQUAD otherwise.
        // Kind "hot" -- normal lifecycle, dispatch suppression applies.
        private _contestedNow = ((_pos nearEntities [["CAManBase"], 500]) findIf {
            side group _x isEqualTo independent && {!captive _x} && {alive _x}
        }) != -1;
        private _contestTicks = _entry param [5, 0];
        if (_contestedNow) then {
            _contestTicks = _contestTicks + 1;
            _entry set [5, _contestTicks];
            _dirty = true;
            if (_contestTicks >= 2 && {count BO_HAL_activeOps < BO_HAL_maxConcurrentOps}) then {
                private _suppressed = (BO_HAL_activeOps findIf {
                    ((_x select 5) distance2D _pos) < 500
                    && {(_now - (_x select 7)) < 300}
                    && {(_x select 12) in ["hot", "field"]}
                }) != -1;
                if (!_suppressed) then {
                    private _catalog = call BO_HAL_fnc_packageCatalog;
                    private _relPkg = [];
                    {
                        if (_relPkg isEqualTo []) then {
                            private _id = _x;
                            private _ci = _catalog findIf { (_x select 0) isEqualTo _id };
                            if (_ci >= 0 && {[_catalog select _ci] call BO_HAL_fnc_packageEligible}) then {
                                _relPkg = _catalog select _ci;
                            };
                        };
                    } forEach ["AIR_ASSAULT", "LIGHT_ARMOR", "MED_SQUAD", "LGT_INFANTRY"];
                    if (_relPkg isNotEqualTo []) then {
                        private _relOp = [_relPkg, _pos, "hot"] call BO_HAL_fnc_launchPackage;
                        if (_relOp > 0) then {
                            _entry set [5, 0];
                            ["garrison_relief", [_relOp, _base, _relPkg select 0]] call BO_HAL_fnc_aar;
                            private _rmsg = format ["HAL relief column op=%1 -> besieged %2 (%3)", _relOp, _base, _relPkg select 0];
                            BO_LOG_INFO("hal", _rmsg);
                        };
                    };
                };
            };
        } else {
            if (_contestTicks > 0) then { _entry set [5, 0]; _dirty = true };
        };

        if (_current >= _target * 0.7) then {
            _entry set [3, 0];
        } else {
            _entry set [3, _deficitTicks + 1];
            _dirty = true;

            private _inbound = (BO_HAL_activeOps findIf {
                (_x select 12) isEqualTo "garrisonReinforce"
                && {((_x select 14) param [0, ""]) isEqualTo _base}
            }) != -1;
            private _contested = ((_pos nearEntities [["CAManBase"], 500]) findIf {
                side group _x isEqualTo independent && {!captive _x} && {alive _x}
            }) != -1;

            private _men = ((_target - _current) max 4) min 8;
            private _vehCls = if (_men <= 4) then {
                missionNamespace getVariable ["OT_NATO_Vehicle_Transport_Light", ""]
            } else {
                private _tr = missionNamespace getVariable ["OT_NATO_Vehicle_Transport", []];
                if (_tr isEqualType "") then { _tr } else { _tr param [0, ""] }
            };
            private _cost = 25 * _men + 60;

            if ((_deficitTicks + 1) >= 2 && {!_inbound} && {!_contested}
                && {(_now - _lastReinforce) > 3600}
                && {_res >= (_cost + 150)}
                && {_vehCls isNotEqualTo ""}
                && {count BO_HAL_activeOps < BO_HAL_maxConcurrentOps}) then {

                private _origin = [_pos, false] call BO_HAL_fnc_pickLaunchOrigin;
                if (_origin isNotEqualTo []) then {
                    private _pool = missionNamespace getVariable ["BO_HAL_riflePool", []];
                    if (_pool isNotEqualTo []) then {
                        private _classes = [missionNamespace getVariable ["OT_NATO_Unit_TeamLeader", ""]];
                        for "_i" from 2 to _men do { _classes pushBack (selectRandom _pool) };
                        _classes = _classes select { _x isNotEqualTo "" };

                        ([_origin, _pos, _classes, _vehCls, "ground", false] call BO_HAL_fnc_spawnGroup)
                            params ["_grp", "_veh", "_crewGrp"];

                        if (!isNull _grp) then {
                            server setVariable ["NATOresources", (_res - _cost) max 0, true];
                            [_grp, false] call BO_HAL_fnc_dressGroup;

                            private _opId = (server getVariable ["BO_HAL_opCounter", 0]) + 1;
                            server setVariable ["BO_HAL_opCounter", _opId];
                            _grp setVariable ["BO_HAL_op", _opId, false];
                            _grp setVariable ["initialStrength", (count units _grp) max 1, false];
                            if (!isNull _crewGrp) then { _crewGrp setVariable ["BO_HAL_op", _opId, false] };

                            BO_HAL_activeOps pushBack [
                                _opId, "GARRISON_REINFORCE", _grp, _veh, _crewGrp, +_pos, +_origin,
                                _now, "transit", count units _grp, 0, _cost, "garrisonReinforce", _now,
                                [_base]
                            ];

                            _entry set [3, 0];
                            _entry set [4, _now];

                            ["garrison_convoy", [_opId, _base, _men, _cost]] call BO_HAL_fnc_aar;
                            private _msg = format ["HAL garrison convoy op=%1 -> %2 (%3 men, cost %4, deficit %5/%6)",
                                _opId, _base, _men, _cost, _current, _target];
                            BO_LOG_INFO("hal", _msg);
                        };
                    };
                };
            };
        };
    };
} forEach _reg;

if (_dirty) then { server setVariable ["BO_HAL_garrisonTargets", _reg] };
