#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_halAdminCmd
 *
 * Server-side dispatcher for the Zeus HAL admin toolkit. All HAL state
 * lives in the server's missionNamespace, so the ZEN modules (client
 * side) funnel through here. Same privilege model as the other
 * destructive remoteExec targets: server (0), hosting player (2), or
 * logged-in admin -- Generals don't qualify (and can't place modules
 * anyway; this is the defense-in-depth layer).
 *
 * Commands:
 *   "status"   []               -- readout hinted back to the caller
 *   "tick"     []               -- force a full strategic tick now
 *   "clearops" []               -- wind down every active op (refunds)
 *   "silent"   [n]              -- set the dwell counter (discovery test)
 *   "heat"     [pos, amt]       -- bump regional heat at pos
 *   "maxops"   [n]              -- runtime concurrent-op cap (1..12)
 *   "spawnpkg" [pkgId, tgtPos]  -- force-launch a package at a target:
 *                                  budget-neutral (cost pre-funded then
 *                                  debited), WL gate bypassed, faction
 *                                  vars and bases-only origin still
 *                                  apply (no wrong-faction spawns).
 *
 * Params: 0: STRING cmd, 1: ARRAY args, 2: NUMBER caller owner id
 */

SERVER_ONLY;

private _ro = remoteExecutedOwner;
if (_ro > 2 && {(admin _ro) isNotEqualTo 2}) exitWith {
    private _wmsg = format ["halAdminCmd: rejected non-admin caller (owner %1)", _ro];
    BO_LOG_WARN("hal", _wmsg);
};

params [["_cmd", "", [""]], ["_args", [], [[]]], ["_caller", 0, [0]]];

private _reply = {
    params ["_text", "_caller"];
    if (_caller >= 2) then {
        _text remoteExec ["hint", _caller, false];
    } else {
        hint _text;
    };
};

switch (toLower _cmd) do {

    case "status": {
        private _res = server getVariable ["NATOresources", 0];
        private _wl = round (server getVariable ["BO_warLevel", 1]);
        private _ops = missionNamespace getVariable ["BO_HAL_activeOps", []];
        private _opLines = "";
        {
            _opLines = _opLines + format ["\n  #%1 %2 [%3] %4", _x select 0, _x select 1, _x select 12, _x select 8];
        } forEach _ops;
        private _heat = missionNamespace getVariable ["BO_HAL_heatCache", []];
        private _heatSorted = [_heat, [], { -(_x select 1) }, "ASCEND"] call BIS_fnc_sortBy;
        private _heatLines = "";
        {
            if (_forEachIndex < 3) then {
                _heatLines = _heatLines + format ["\n  %1: %2", _x select 0, round ((_x select 1) * 100) / 100];
            };
        } forEach _heatSorted;
        private _text = format [
            "HAL STATUS\nenabled: %1\nresources: %2 (WL %3/10)\nconsistency: %4  tempo: %5\nsilentTicks: %6\nops (%7/%8):%9\nfield pool: %10\ntop heat:%11\ngarrison targets: %12",
            missionNamespace getVariable ["BO_HAL_enabled", false],
            _res, _wl,
            round ((missionNamespace getVariable ["BO_HAL_consistency", 0]) * 100) / 100,
            round ((missionNamespace getVariable ["BO_HAL_tempo", 0]) * 100) / 100,
            server getVariable ["BO_HAL_silentTicks", 0],
            count _ops, missionNamespace getVariable ["BO_HAL_maxConcurrentOps", 4],
            _opLines,
            count (missionNamespace getVariable ["BO_HAL_fieldPool", []]),
            _heatLines,
            count (server getVariable ["BO_HAL_garrisonTargets", []])
        ];
        [_text, _caller] call _reply;
    };

    case "tick": {
        BO_HAL_lastTick = 0;
        call BO_HAL_fnc_tick;
        ["HAL: full tick forced", _caller] call _reply;
        ["admin_force_tick", []] call BO_HAL_fnc_aar;
    };

    case "clearops": {
        private _ops = +(missionNamespace getVariable ["BO_HAL_activeOps", []]);
        {
            if ((_x select 12) isEqualTo "field") then {
                [_x, "admin_clear"] call BO_HAL_fnc_releaseFieldGroup;
            } else {
                [_x, true, "admin_clear"] call BO_HAL_fnc_recycleOp;
            };
        } forEach _ops;
        [format ["HAL: %1 op(s) wound down", count _ops], _caller] call _reply;
    };

    case "silent": {
        private _n = round (_args param [0, 0]) max 0;
        server setVariable ["BO_HAL_silentTicks", _n, true];
        [format ["HAL: silentTicks = %1", _n], _caller] call _reply;
    };

    case "heat": {
        _args params [["_pos", [0,0,0], [[]]], ["_amt", 0.5, [0]]];
        [_pos, _amt max 0 min 1] call BO_HAL_fnc_heatBump;
        call BO_HAL_fnc_persist;
        [format ["HAL: heat +%1 near %2", _amt, _pos call OT_fnc_nearestTown], _caller] call _reply;
    };

    case "maxops": {
        private _n = (round (_args param [0, 4])) max 1 min 12;
        BO_HAL_maxConcurrentOps = _n;
        [format ["HAL: maxConcurrentOps = %1", _n], _caller] call _reply;
    };

    case "spawnpkg": {
        _args params [["_pkgId", "", [""]], ["_tgt", [], [[]]]];
        if (_pkgId isEqualTo "" || {_tgt isEqualTo []}) exitWith {};
        private _catalog = call BO_HAL_fnc_packageCatalog;
        private _idx = _catalog findIf { (_x select 0) isEqualTo _pkgId };
        if (_idx < 0) exitWith { ["HAL: unknown package", _caller] call _reply };
        private _pkg = _catalog select _idx;
        // Budget-neutral force spawn: pre-fund the cost, launchPackage
        // debits it straight back. WL is bypassed by design (admin
        // test tool); missing faction vars still abort in the builder.
        private _res = server getVariable ["NATOresources", 0];
        server setVariable ["NATOresources", _res + (_pkg select 1), true];
        private _kind = ["hot", "recon"] select (_pkgId in ["RECON_GROUND", "RECON_AIR", "RECON_DRONE"]);
        private _opId = [_pkg, _tgt, _kind] call BO_HAL_fnc_launchPackage;
        if (_opId > 0) then {
            [format ["HAL: %1 launched (op %2)", _pkgId, _opId], _caller] call _reply;
        } else {
            // Launch failed after pre-fund: claw the float back.
            server setVariable ["NATOresources", ((server getVariable ["NATOresources", 0]) - (_pkg select 1)) max 0, true];
            [format ["HAL: %1 launch aborted (no base origin / cap / builder)", _pkgId], _caller] call _reply;
        };
    };

    case "doctrine": {
        (missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]])
            params ["_tS", "_tC", "_tN", "_tM", "_tD", "_tSt", "_tSw"];
        private _d = server getVariable ["BO_HAL_doctrine", []];
        private _fmt = { params ["_x"]; round (_x * 100) };
        private _text = format [
            "HAL DOCTRINE PROFILE (kills sampled: %1)\nsniper: %2%3   cqb: %4%3\nnocturnal: %5%3   mechanized: %6%3\ndemolition: %7%3   stealth: %8%3\nswarm: %9%3\ncommander: %10  supply next: %11s",
            round (_d param [1, 0]),
            [_tS] call _fmt, "%", [_tC] call _fmt,
            [_tN] call _fmt, [_tM] call _fmt,
            [_tD] call _fmt, [_tSt] call _fmt,
            [_tSw] call _fmt,
            [server getVariable ["BO_HAL_cmdBase", "none"], "KIA (successor inbound)"] select (!(server getVariable ["BO_HAL_cmdAlive", false]) && {(server getVariable ["BO_HAL_cmdRespawnAt", 0]) > 0}),
            round ((server getVariable ["BO_supplyNextAt", 0]) - serverTime) max 0
        ];
        [_text, _caller] call _reply;
    };

    default {
        [format ["HAL: unknown command %1", _cmd], _caller] call _reply;
    };
};

[AUDIT_ADMIN, format ["HAL admin cmd: %1 %2", _cmd, _args], [_cmd, _args], "", ""] call BO_fnc_auditServer;
