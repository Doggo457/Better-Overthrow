#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_fobJobsDialog
 *
 * FOB-pool job request. No NPC required -- player initiates from the
 * FOB Y-menu while at a friendly base. Pulls from a curated subset of
 * OT's mission pool that suits "directed operation from your own base"
 * rather than "civilian whisper at the gun dealer".
 *
 * Iterates the pool in shuffled order; for each candidate that passes
 * the condition AND isn't already offered/active/completed, runs the
 * script once. Mission scripts can still return [] internally (e.g.
 * "no valid target NATO position found"), in which case we move on
 * silently and try the next candidate. Only fails outright when every
 * candidate has been tried.
 *
 * Rewards stay on whatever path the mission script uses
 * (OT_fnc_money for personal cash; reconBase splits among contributors).
 */

// Rate-limit guard. Telemetry from one playtest showed this
// function being re-entered at ~30Hz for a sustained minute --
// somewhere between keyboard repeat, button focus, and a stacked
// event handler, the FOB Jobs button was being "clicked" every
// frame. Whatever the upstream cause is, refusing to do anything
// for 1s after the last entry stops the cascade and keeps the
// joboffer dialog from flashing.
if (!isNil "BO_fobJobsDialog_lastCall"
    && { (diag_tickTime - BO_fobJobsDialog_lastCall) < 1.0 }
) exitWith {
    diag_log "[BO_fob] fobJobsDialog: rate-limited (<1s since last entry)";
};
BO_fobJobsDialog_lastCall = diag_tickTime;

// The Y-menu button handler already calls closeDialog 0; doing it
// a second time here was racing with createDialog later in this
// function, manifesting as "press button, nothing happens".
diag_log "[BO_fob] fobJobsDialog: entered";

// If the Y menu (display 8001) is somehow still open when we get
// here, just bail out cleanly. The button click handler already
// did `closeDialog 0` then `CBA_fnc_waitAndExecute 0.3s` before
// calling us, so under normal flow the dialog is gone by now.
// If it isn't (some other code path opened it in the meantime),
// trying to wait for it to close inside a `waitUntil` was tripping
// an SQF parser error on the multi-statement block; cleaner to
// just abort and let the player retry.
if (!isNull (findDisplay 8001)) exitWith {
    diag_log "[BO_fob] fobJobsDialog: display 8001 still open, aborting";
    "Y menu was open -- close it first then press FOB Jobs again" call OT_fnc_notifyMinor;
};

private _fobPool = [
    "MedicalSupplies",
    "Tagging",
    "KillNATO",
    "TransportOperative",
    "GangDrugRun",
    "GangWeaponRun",
    "ShopDelivery",
    "Transformer",
    // BO raid-flavour additions (registered via
    // bo_additions/missions_extension.hpp).
    "BO_RaidSFCamp",
    "BO_HitNATOPatrol",
    "BO_SabotageDepot",
    "BO_HitCheckpoint",
    "BO_HitAAA",
    "BO_SaveMayor",
    "BO_ProtectDefector",
    "BO_PrisonBreak",
    "BO_StealNATOTruck",
    "BO_KillNATOOfficer",
    "BO_PaydayConvoyAmbush",
    // Phase 2 catalog additions
    "BO_BurnFuelCache",
    "BO_DisableRadar",
    "BO_PlantListeningDevice",
    "BO_StealDocuments",
    "BO_BurnNATOFlag",
    "BO_DistributeLeaflets",
    "BO_CollaboratorBurglary",
    "BO_GangLeaderBounty"
];

if (isNil "OT_allJobs") exitWith {
    "FOB jobs not yet initialized -- try again in a moment" call OT_fnc_notifyMinor;
};

private _candidates = OT_allJobs select { (_x select 0) in _fobPool };
if (_candidates isEqualTo []) exitWith {
    "FOB jobs not yet initialized -- try again in a moment" call OT_fnc_notifyMinor;
};

if (isNil "OT_jobsOffered") then { OT_jobsOffered = [] };

private _activeJobs = spawner getVariable ["OT_activeJobIds", []];
private _completed = server getVariable ["OT_completedJobIds", []];

// Walk the pool in shuffled order. For each candidate that passes
// the condition + uniqueness check, RUN the mission script. If the
// script returns [] (mission can't satisfy its own internal setup),
// rewind: unregister the offered ID so it can be re-attempted, and
// try the next candidate. Only commit to a job that gives us a
// non-empty result.
private _shuffled = [_candidates, [], { random 100 }, "ASCEND"] call BIS_fnc_sortBy;

private _committedJob = [];
private _committedId = "";
private _committedExpiry = 0;
private _attempted = [];

{
    _x params ["_name", ["_target", ""], "_condition", "_code", "", "", "_expires"];
    private _id = "";
    private _params = [];
    private _eligible = false;

    call {
        if ((toLowerANSI _target) isEqualTo "base") exitWith {
            private _nearest = player call OT_fnc_nearestObjectiveNoComms;
            _nearest params ["_loc", "_base"];
            private _inSpawnDistance = [_loc] call OT_fnc_inSpawnDistance;
            _id = format ["%1-%2", _name, _base];
            private _stability = server getVariable [format ["stability%1", _loc call OT_fnc_nearestTown], 100];
            if (([_inSpawnDistance, _base, _stability] call _condition)
                && !(_id in _completed)
                && !(_id in _activeJobs)
                && !(_id in OT_jobsOffered)
            ) then {
                _eligible = true;
                _params = [_base, _loc];
            };
        };
        if ((toLowerANSI _target) isEqualTo "town") exitWith {
            private _nearest = player call OT_fnc_nearestTown;
            private _loc = server getVariable _nearest;
            private _inSpawnDistance = [_loc] call OT_fnc_inSpawnDistance;
            _id = format ["%1-%2", _name, _nearest];
            private _stability = server getVariable [format ["stability%1", _nearest], 100];
            if (([_inSpawnDistance, _stability, _nearest] call _condition)
                && !(_id in _completed)
                && !(_id in _activeJobs)
                && !(_id in OT_jobsOffered)
            ) then {
                _eligible = true;
                _params = [_nearest];
            };
        };
    };

    if (_eligible) then {
        _attempted pushBack _id;
        private _job = [_id, _params] call _code;
        if (_job isNotEqualTo []) then {
            _committedJob = _job;
            _committedId = _id;
            _committedExpiry = _expires;
        };
    };

    if (_committedJob isNotEqualTo []) exitWith {};
} forEach _shuffled;

if (_committedJob isEqualTo []) exitWith {
    private _msg = if (_attempted isEqualTo []) then {
        "No FOB jobs available right now. Capture more towns or wait for stability to shift."
    } else {
        format ["Tried %1 mission(s); none could find a valid target at this FOB right now. Try again later or move FOB.", count _attempted]
    };
    _msg call OT_fnc_notifyMinor;
};

OT_jobShowing = _committedJob;
OT_jobShowingID = _committedId;
OT_jobShowingExpiry = _committedExpiry;
OT_jobsOffered pushBack _committedId;

OT_jobShowingType = "resistance";
private _opened = createDialog "OT_dialog_joboffer";
if (!_opened) exitWith {
    // Last-resort: dialog couldn't open (UI busy / blocked). Unregister
    // the offered ID so the player can try again without burning the
    // candidate. Hint so they know to retry.
    OT_jobsOffered = OT_jobsOffered - [_committedId];
    diag_log "[BO_fob] createDialog OT_dialog_joboffer returned false; aborting offer";
    "FOB jobs dialog couldn't open -- press the button again" call OT_fnc_notifyMinor;
};
disableSerialization;

_committedJob params ["_info"];
_info params ["_title", "_desc"];

private _textctrl = (findDisplay 8000) displayCtrl 1199;
_textctrl ctrlSetStructuredText parseText format [
    "<t align='center' size='1.1'>%1</t><br/><br/><t align='center' size='0.8'>%2</t><br/>",
    _title,
    _desc
];

[AUDIT_MISSION, format ["FOB job offered: %1", _committedId], [_committedId], getPlayerUID player, name player] call BO_fnc_audit;

_committedJob
