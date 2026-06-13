#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_tick
 *
 * The HAL heartbeat (build doc section 6, v2-complete). Silence is the
 * rule: three gates compound (eligibility floor -> WL-derived
 * consistency roll -> tempo/branch conditions) and HAL doing nothing is
 * the correct output most ticks.
 *
 * Addendum locks honored here:
 *   #15 consistency = clamp(WL/10, 0.05, 0.9), recomputed every tick
 *   #8  zero notifications -- the only outputs are world state
 *   D3  silentTicks zeroed on load (postLoadHydrate)
 *
 * Param 0 (optional): "partial" -- provocation interrupt (V1): skips
 * the interval AND consistency gates, runs the hot branch only.
 */

SERVER_ONLY;
if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};

params [["_mode", "full", [""]]];
private _partial = _mode isEqualTo "partial";

private _now = serverTime;     // HAL's own anchor (session-lifetime)
private _gameNow = time;       // matches NATOknownTargets slot 5 writers

// ---- interval gate (garrison-scaled) --------------------------------
// (exitWith only escapes its immediate scope, so the gate is computed
// at top level rather than inside an if-block.)
private _due = if (_partial) then {
    (_now - BO_HAL_lastTick) >= 60
} else {
    private _garrisonScale = ({ side _x isEqualTo west } count allUnits) / 200;
    private _interval = ((BO_HAL_tickIntervalBase + BO_HAL_tickIntervalBase * _garrisonScale) min 2400) max 900;
    (_now - BO_HAL_lastTick) >= _interval
};
if (!_due) exitWith {};
BO_HAL_lastTick = _now;

// ---- 1. decay --------------------------------------------------------
call BO_HAL_fnc_decayTargets;

// ---- 2. live filter (slot 5 is engine `time`, NOT serverTime) -------
if (isNil "NATOknownTargets") then { NATOknownTargets = [] };
private _live = NATOknownTargets select {
    private _obj = _x param [3, objNull];
    !isNull _obj
    && { alive _obj }
    && { !(_obj isKindOf "Man") || { !captive _obj } }
    && { (_gameNow - (_x param [5, 0])) < 900 }
};

// ---- 3. silent ticks -------------------------------------------------
private _silent = server getVariable ["BO_HAL_silentTicks", 0];
if (!_partial) then {
    _silent = if (count _live isEqualTo 0) then { _silent + 1 } else { 0 };
    server setVariable ["BO_HAL_silentTicks", _silent, true];
};

// ---- 4. heat + tempo + doctrine ---------------------------------------
if (!_partial) then {
    call BO_HAL_fnc_heatRecompute;
    call BO_HAL_fnc_tempoRecompute;
    call BO_HAL_fnc_doctrineTraits;   // decay + re-profile the resistance
};
(missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]])
    params ["_tSniper", "_tCqb", "_tNoct", "_tMech", "_tDemo", "_tStealth", "_tSwarm"];

// ---- 5. WL-derived consistency gate (locked #15, #27 revision) -------
// War Level is the independent aggression dial (server var), no longer
// derived from the budget. Decays slowly while the island is quiet.
if (!_partial && {count _live isEqualTo 0} && {_silent >= 1}) then {
    [-0.05, "quiet decay"] call BO_HAL_fnc_warLevelBump;
};
private _wl = round (server getVariable ["BO_warLevel", 1]);
BO_HAL_consistency = ((_wl / 10) max 0.05) min 0.9;

// Counter-doctrine: a proven night fighter gets hunted at night --
// the network leans into darkness instead of sleeping through it.
if (_tNoct >= 0.5 && {sunOrMoon < 0.5}) then {
    BO_HAL_consistency = (BO_HAL_consistency + 0.15) min 0.95;
};
// VCOM mine warfare flips on against a vehicle-heavy resistance.
if (missionNamespace getVariable ["BO_HAL_vcomActive", false] && {!isNil "Vcm_Settings"}) then {
    VCM_MINEENABLED = _tMech >= 0.5;
};

// Decapitation effect: with the regional commander dead and his
// successor not yet seated, the network barely functions.
if (serverTime < (server getVariable ["BO_HAL_disruptedUntil", 0])) then {
    BO_HAL_consistency = 0.05;
};

private _gatePassed = _partial || { random 1 <= BO_HAL_consistency };

// ---- 6. branch --------------------------------------------------------
if (_gatePassed) then {
    switch (true) do {

        // HOT: freshest-heaviest live sighting gets a threat-matched response.
        case (count _live > 0): {
            private _best = [];
            private _bestScore = -1;
            {
                private _score = (_x param [2, 1]) * 1000 - (_gameNow - (_x param [5, 0]));
                if (_score > _bestScore) then { _bestScore = _score; _best = _x };
            } forEach _live;
            private _tpos = _best param [1, [0,0,0]];

            // SURGE check first (locked #30): a real fight for an area
            // -- 3+ live rebels clustered, or NATO already beaten here
            // twice -- justifies the sanctioned full-send: a combined-
            // arms wave, all at once, to push them out. Gates keep it
            // rare: WL>=5, 45-min global cooldown, budget + free slots
            // (validated inside launchSurge).
            private _surged = false;
            if (_wl >= 5
                && {(_now - (missionNamespace getVariable ["BO_HAL_lastSurge", -1e7])) > 2700}) then {
                private _clusterLive = {
                    ((_x param [1, [0,0,0]]) distance2D _tpos) < 400
                } count _live;
                private _recentLosses = {
                    ((_x select 0) distance2D _tpos) < 800
                    && {(_now - (_x select 1)) < 1800}
                } count BO_HAL_setbacks;
                // Swarm fighters lower the surge bar: massed rebels get
                // answered in kind one cluster-step earlier.
                private _clusterNeed = [3, 2] select (_tSwarm >= 0.5);
                if (_clusterLive >= _clusterNeed || {_recentLosses >= 2}) then {
                    _surged = ([_tpos] call BO_HAL_fnc_launchSurge) > 0;
                };
            };

            // Dispatch suppression: ONE response wave per fight. Any
            // live hot/field op within 700m suppresses for its whole
            // lifetime -- escalation belongs to the reinforce engine,
            // not to stacking fresh packages (the full-send spam).
            private _suppressed = _surged || {(BO_HAL_activeOps findIf {
                ((_x select 5) distance2D _tpos) < 700
                && {(_x select 12) in ["hot", "field"]}
            }) != -1};

            // Defeat cooldown (locked #28): after losing an op in this
            // area, HAL stays out for 15 min and regroups -- unless
            // tempo is raging (>0.8), where it presses anyway.
            if (!_suppressed && {BO_HAL_tempo <= 0.8}) then {
                _suppressed = (BO_HAL_setbacks findIf {
                    ((_x select 0) distance2D _tpos) < 600
                    && {(_now - (_x select 1)) < 900}
                }) != -1;
            };

            if (!_suppressed) then {
                // Command the standing army first (free), spawn second.
                private _dispatched = [_tpos] call BO_HAL_fnc_taskFieldGroup;
                if (!_dispatched) then {
                    private _pkg = [_best] call BO_HAL_fnc_pickHotPackage;
                    if (_pkg isNotEqualTo []) then {
                        _dispatched = ([_pkg, _tpos, "hot"] call BO_HAL_fnc_launchPackage) > 0;
                    };
                };
                // ISR adjunct: a Darter shadows the response (WL>=3,
                // 20%) so the ground element doesn't arrive blind.
                // launchPackage enforces the one-Darter-aloft cap.
                if (_dispatched && {_wl >= 3} && {random 1 < 0.2}) then {
                    private _catalog = call BO_HAL_fnc_packageCatalog;
                    private _di = _catalog findIf { (_x select 0) isEqualTo "RECON_DRONE" };
                    if (_di >= 0 && {[_catalog select _di] call BO_HAL_fnc_packageEligible}) then {
                        [_catalog select _di, _tpos, "recon"] call BO_HAL_fnc_launchPackage;
                    };
                };
            };
        };

        // COLD: discovery escalation by dwell (section 10 + V11).
        case (_silent >= 2 && {!_partial}): {
            private _region = call BO_HAL_fnc_pickHeatRegion;
            if (_region isNotEqualTo []) then {
                _region params ["_rTown", "_rPos"];
                private _catalog = call BO_HAL_fnc_packageCatalog;
                private _launchById = {
                    params ["_id", "_pos"];
                    private _i = _catalog findIf { (_x select 0) isEqualTo _id };
                    if (_i >= 0) then {
                        private _p = _catalog select _i;
                        if ([_p] call BO_HAL_fnc_packageEligible) then {
                            [_p, _pos, ["recon", "hunter"] select (_id isEqualTo "CTRG_HUNTER")] call BO_HAL_fnc_launchPackage;
                        };
                    };
                };
                // Counter-doctrine: a proven ghost (suppressed, lone)
                // gets the CTRG hunt two dwell-steps earlier.
                private _ctrgGate = [8, 6] select (_tStealth >= 0.6);
                switch (true) do {
                    case (_silent >= _ctrgGate): {
                        // CTRG hunt on the freshest decayed sighting, else the heat region.
                        private _hpos = if (BO_HAL_lastKnown isNotEqualTo []) then { BO_HAL_lastKnown select 0 } else { _rPos };
                        ["CTRG_HUNTER", _hpos] call _launchById;
                    };
                    case (_silent >= 6): {
                        ["RECON_GROUND", _rPos getPos [400 + random 400, random 360]] call _launchById;
                        ["RECON_GROUND", _rPos getPos [400 + random 400, random 360]] call _launchById;
                        [["RECON_AIR", "RECON_DRONE"] select (random 1 < 0.5), _rPos] call _launchById;
                    };
                    case (_silent >= 4): {
                        ["RECON_GROUND", _rPos] call _launchById;
                        [["RECON_AIR", "RECON_DRONE"] select (random 1 < 0.5), _rPos] call _launchById;
                    };
                    default {
                        // The quiet-hours look: 60% a Hunter with scouts,
                        // 40% just an engine at altitude.
                        [["RECON_GROUND", "RECON_DRONE"] select (random 1 < 0.4), _rPos] call _launchById;
                    };
                };
            };

            // Greenfor alternates with discovery once the player has been
            // quiet a while: hit the economy where it lives (V5).
            if (_silent >= 2 && {random 1 < 0.5}) then {
                call BO_HAL_fnc_greenforBranch;
            };
        };

        // GREENFOR: player quiet but assets known (M6 third branch).
        case ((count _live isEqualTo 0) && {!_partial}): {
            call BO_HAL_fnc_greenforBranch;
        };

        default {};
    };
};

if (_partial) exitWith {
    // Partial pass: hot dispatch only; bookkeeping stays on the full tick.
    ["tick_partial", [count _live]] call BO_HAL_fnc_aar;
};

// ---- 7. FOB watch (V4) ------------------------------------------------
if (_gatePassed) then { call BO_HAL_fnc_fobWatch };

// ---- 7b. garrison reinforcements (Phase 3 marquee) ---------------------
// Doctrine, not aggression: runs every full tick regardless of the
// consistency roll. Depleted bases rebuild via interceptable convoys.
call BO_HAL_fnc_garrisonReinforce;

// ---- 8. op evaluation moved to its own 60s PFH (fn_init) --------------
// The strategic tick only PLANS; the reactive layer answers in
// seconds (retreats, arrivals, interdiction clocks).

// ---- 9. discovery ellipse + persist -----------------------------------
call BO_HAL_fnc_discoveryEllipse;
call BO_HAL_fnc_persist;

["tick", [count _live, _silent, count BO_HAL_activeOps, _wl,
    round (BO_HAL_consistency * 100) / 100, round (BO_HAL_tempo * 100) / 100]] call BO_HAL_fnc_aar;
