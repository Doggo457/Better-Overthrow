#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_fobWatch
 *
 * V4: FOB recon + overflight ONLY (sabotage stays cut -- safe-zone
 * promise, locked decision #9). The signature moment: a Hunter parks
 * 800m out, two scouts glass the FOB, they leave without firing.
 *
 * Sanctuary rules (locked #9 + addendum):
 *   - disabled by BO_HAL_disableFOBActions
 *   - skipped while any player is at the FOB (within 400m)
 *   - per-FOB cooldown (BO_HAL_fobProbeCooldown, default 6h)
 *   - global max ONE concurrent FOB action
 *   - probe chance per tick (BO_HAL_fobProbeChance, default 0.10)
 *
 * Returns: BOOL launched
 */

SERVER_ONLY;

if (BO_HAL_disableFOBActions) exitWith { false };

private _reg = server getVariable ["BO_HAL_fobRegistry", []];
if (_reg isEqualTo []) exitWith { false };

private _now = serverTime;
private _players = allPlayers select { alive _x };

// Presence bookkeeping runs EVERY tick (not just on probe rolls): the
// v3 sabotage gate needs to know how long the player has been away.
{
    _x params ["_key", "_name", "_pos", "_lastProbe"];
    if (_lastProbe > _now) then { _x set [3, 0] };                   // serverTime reset clamp
    // Stale presence stamp clamps CONSERVATIVE (to now, not 0): after a
    // load HAL cannot know how long the player has been away, so the
    // sabotage away-gate restarts from scratch -- sanctuary-safe.
    if ((_x param [4, 0]) > _now) then { _x set [4, _now] };
    if ((_players findIf { (_x distance2D _pos) < 400 }) != -1) then {
        _x set [4, _now]; // set auto-extends legacy 4-slot entries
    };
} forEach _reg;
server setVariable ["BO_HAL_fobRegistry", _reg];

if (BO_HAL_fobActionActive) exitWith { false };

// ---- v3 FOB sabotage (locked decision #9, gates in full) -------------
// Requires: player away from THIS FOB for 2+ tick intervals AND a
// registered factory/business within 600m of the flag. Low roll --
// the sanctuary promise stays the default experience.
if (random 1 < (BO_HAL_fobProbeChance * 0.5)) then {
    private _sCands = _reg select {
        _x params ["_key", "_name", "_pos", "_lastProbe"];
        private _away = _now - (_x param [4, 0]);
        ((_now - _lastProbe) > BO_HAL_fobProbeCooldown || {_lastProbe isEqualTo 0})
        && {_away > (2 * BO_HAL_tickIntervalBase)}
        && {(_players findIf { (_x distance2D _pos) < 400 }) == -1}
    };
    private _launchedSab = false;
    {
        if (!_launchedSab) then {
            _x params ["_key", "_name", "_pos"];
            private _assets = ((server getVariable ["BO_buildFactories", []])
                + (server getVariable ["BO_buildBusinesses", []])) select {
                !isNull _x && {alive _x} && {(_x distance2D _pos) < 600}
            };
            if (_assets isNotEqualTo []) then {
                private _catalog = call BO_HAL_fnc_packageCatalog;
                private _sIdx = _catalog findIf { (_x select 0) isEqualTo "FACTORY_SABOTAGE" };
                if (_sIdx >= 0 && {[_catalog select _sIdx] call BO_HAL_fnc_packageEligible}) then {
                    private _asset = selectRandom _assets;
                    private _sOp = [_catalog select _sIdx, getPosATL _asset, "fob"] call BO_HAL_fnc_launchPackage;
                    if (_sOp > 0) then {
                        _x set [3, _now];
                        server setVariable ["BO_HAL_fobRegistry", _reg];
                        BO_HAL_fobActionActive = true;
                        _launchedSab = true;
                        ["fob_sabotage", [_name]] call BO_HAL_fnc_aar;
                    };
                };
            };
        };
    } forEach _sCands;
    if (_launchedSab) exitWith { true };
};
// Sabotage may have taken the single concurrent FOB-action slot.
if (BO_HAL_fobActionActive) exitWith { true };

// Counter-doctrine: probes double at night against a proven night
// fighter -- the network watches the hours you own.
private _probeChance = BO_HAL_fobProbeChance;
private _tNoct = (missionNamespace getVariable ["BO_HAL_traits", [0,0,0,0,0,0,0]]) param [2, 0];
if (_tNoct >= 0.5 && {sunOrMoon < 0.5}) then { _probeChance = _probeChance * 2 };
if (random 1 > _probeChance) exitWith { false };

// Candidates: cooldown elapsed, nobody home.
private _cands = _reg select {
    _x params ["_key", "_name", "_pos", "_lastProbe"];
    ((_now - _lastProbe) > BO_HAL_fobProbeCooldown || {_lastProbe isEqualTo 0})
    && {(_players findIf { (_x distance2D _pos) < 400 }) == -1}
};
if (_cands isEqualTo []) exitWith { false };

private _entry = selectRandom _cands;
_entry params ["_key", "_name", "_pos"];

private _catalog = call BO_HAL_fnc_packageCatalog;
private _pkgId = ["RECON_GROUND", "RECON_AIR"] select (random 1 < 0.4);
private _idx = _catalog findIf { (_x select 0) isEqualTo _pkgId };
if (_idx < 0) exitWith { false };
private _pkg = _catalog select _idx;
if (!([_pkg] call BO_HAL_fnc_packageEligible)) then {
    // Fall back to the other recon flavor before giving up.
    _pkgId = ["RECON_AIR", "RECON_GROUND"] select (_pkgId isEqualTo "RECON_AIR");
    _idx = _catalog findIf { (_x select 0) isEqualTo _pkgId };
    if (_idx >= 0) then { _pkg = _catalog select _idx };
};
if (!([_pkg] call BO_HAL_fnc_packageEligible)) exitWith { false };

private _opId = [_pkg, _pos, "fob"] call BO_HAL_fnc_launchPackage;
if (_opId < 0) exitWith { false };

_entry set [3, _now];
server setVariable ["BO_HAL_fobRegistry", _reg];
BO_HAL_fobActionActive = true;
["fob_probe", [_name, _pkgId]] call BO_HAL_fnc_aar;
true
