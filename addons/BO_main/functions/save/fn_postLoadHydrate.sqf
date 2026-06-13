#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_postLoadHydrate
 *
 * Runs after a save is loaded (or after a fresh-start mission init).
 * With the team / general / factory system removed, this is now a
 * thin marker that stamps BO_dataVersion so re-loads know the save
 * has touched BO at least once and emits an audit entry.
 *
 * Idempotent.
 */

SERVER_ONLY;

// Only run on an actual load. postInit dispatches this unconditionally,
// but on NEW (and on the empty-StartupType bootstrap path before
// initPlayerLocal sets it) the BO_dataVersion stamp is meaningless --
// there's no save to mark as touched.
private _startup = server getVariable ["StartupType", ""];
if (_startup isNotEqualTo "LOAD") exitWith {
    private _msg = format ["postLoadHydrate skipped (StartupType=%1)", _startup];
    BO_LOG_INFO("save", _msg);
};

private _t0 = diag_tickTime;
BO_LOG_INFO("save","postLoadHydrate started");

// Civilian saboteur events: live npc/marker references from the
// previous session are objNull / dead. Clear the registry so the
// loop re-seeds cleanly. Sabotage history (date + name + effect)
// is NOT wiped -- the 24h intel reveal should survive a load.
server setVariable ["BO_activeCivilianEvents", [], true];

server setVariable ["BO_dataVersion", 1, true];

// HAL silent-ticks counter. Locked decision D3 Option A (see
// PLAN_HAL/HAL_BUILD_ORDER.md addendum): the dwell counter must
// NOT survive a save/load round-trip, otherwise a load mid-dwell
// would resume HAL in whatever silent state the save froze it at,
// against AI that has been despawned and respawned with fresh
// nav/los state. Reset to 0 so the first post-load tick re-evaluates
// from a clean baseline. Networked broadcast so JIP clients see the
// reset (Recon dialog will read this in a later HAL phase).
server setVariable ["BO_HAL_silentTicks", 0, true];

// ------------------------------------------------------------------
// BO world demand events: re-paint badge markers for any restored
// active event. BO_activeWorldEvents was already restored by the
// slot-1 server-var loop in loadGame; markers are session-local
// createMarker outputs that don't persist, so we repaint them here.
// Idempotent: deleteMarker is a no-op on a missing name.
// ------------------------------------------------------------------
private _activeEvents = server getVariable ["BO_activeWorldEvents", []];
{
    _x params [
        ["_eTown", "", [""]],
        ["_eType", "", [""]],
        ["_eStart", [], [[]]],
        ["_eEnd",   [], [[]]],
        ["_eItems", [], [[]]],
        ["_eMul",   1,  [0]],
        ["_eid", "", [""]]
    ];
    private _posTown = server getVariable _eTown;
    if (!isNil "_posTown") then {
        private _mkName = format ["bo_evt_%1", _eid];
        deleteMarker _mkName;
        createMarker [_mkName, _posTown];
        _mkName setMarkerType "ot_Shop";
        _mkName setMarkerSize [0.6, 0.6];
        _mkName setMarkerColor "ColorYellow";
        // Lift the display name from BO_eventCatalog if it's already
        // built (preInit runs before postLoadHydrate); otherwise fall
        // back to the raw type token.
        private _dname = _eType;
        {
            if ((_x select 0) isEqualTo _eType) exitWith { _dname = _x select 1 };
        } forEach (missionNamespace getVariable ["BO_eventCatalog", []]);
        _mkName setMarkerText (format ["!%1", _dname]);
    };
} forEach _activeEvents;
if (_activeEvents isNotEqualTo []) then {
    private _hmsg = format ["postLoadHydrate: restored %1 event marker(s)", count _activeEvents];
    BO_LOG_INFO("events", _hmsg);
};

// BO recon: rebase serverTime expiries off the persisted in-game date.
// serverTime resets on load; without this, BO_activeRecon entries either
// over-run their duration or expire-immediately. The world-clock _expireDate
// (slot 4) is the canonical persisted truth; this rebase rewrites slot 3
// (_expireServerTime) so the sweep + client PFH read correct deltas. MUST
// run BEFORE clients fire reconRebuildClient.
[] call BO_fnc_reconRebaseServerTimes;

// BO: garage / insurance re-install. Killed EHs don't survive
// save/load round-trip; postLoadHydrateGarage walks live vehicles
// and re-installs the EH on anything still flagged BO_insured.
[] call BO_fnc_postLoadHydrateGarage;

// BO police: registry rebind. NetIds, markers, flag, and spawner
// registrations don't survive serialization; rebuild from the
// persistent slot-0/1/2/8/11 fields. MUST run before
// initNATOPoliceStations re-scans, so its LOAD-path gate sees the
// hydrated registry and skips a duplicate spawn.
[] call BO_fnc_postLoadHydratePolice;

private _elapsed = diag_tickTime - _t0;
[AUDIT_SAVE, format ["postLoadHydrate complete in %1s", _elapsed], [_elapsed], "", ""] call BO_fnc_auditServer;
private _doneMsg = format ["postLoadHydrate complete in %1s", _elapsed];
BO_LOG_INFO("save", _doneMsg);
