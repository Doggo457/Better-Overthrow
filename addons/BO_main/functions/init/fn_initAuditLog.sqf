#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_initAuditLog
 *
 * Ensure the BO_auditLog server-namespace hashmap exists and has at
 * least empty arrays for every known category. Pre-creating buckets
 * makes the in-game viewer's category filter dropdown stable across
 * sessions even before any events have fired.
 *
 * Also starts the daily archive rotation loop if enabled.
 *
 * Idempotent: safe to call multiple times.
 */

if (!isServer) exitWith {};

private _log = server getVariable ["BO_auditLog", createHashMap];

private _categories = [
    AUDIT_ATM, AUDIT_MISSION, AUDIT_SAVE,
    AUDIT_ADMIN, AUDIT_PRICING, AUDIT_GARBAGE,
    AUDIT_LOGISTICS, AUDIT_CIVILIAN, AUDIT_INTEL,
    AUDIT_EVENTS
];

{
    if !(_x in _log) then {
        _log set [_x, []];
    };
} forEach _categories;

server setVariable ["BO_auditLog", _log, true];

// ------------------------------------------------------------------
// Daily archive loop.
//
// At in-game midnight, snapshot the current log to
// BO_auditArchive_<YYYY-MM-DD> and trim archives older than
// BO_auditArchiveDays.
//
// Implemented as a CBA action loop so it ticks alongside OT's other
// scheduled tasks.
// ------------------------------------------------------------------
if (BO_auditDailyArchive && {isNil "BO_auditArchiveLoopHandle"}) then {
    BO_auditArchiveLastDate = date select 2;

    // Daily-rotation tick runs through CBA's per-frame handler at a
    // 60s cadence. Cheap: the body short-circuits unless the in-game
    // day actually changed since the last tick.
    BO_auditArchiveLoopHandle = [
        {
            private _today = date select 2;
            if (_today isEqualTo BO_auditArchiveLastDate) exitWith {};
            BO_auditArchiveLastDate = _today;

            private _m = date select 1;
            private _stamp = format ["%1-%2-%3",
                date select 0,
                (if (_m < 10) then { format ["0%1", _m] } else { str _m }),
                (if (_today < 10) then { format ["0%1", _today] } else { str _today })
            ];

            private _log = server getVariable ["BO_auditLog", createHashMap];
            private _snap = createHashMap;
            {
                _snap set [_x, +(_log get _x)];
            } forEach (keys _log);
            server setVariable [format ["BO_auditArchive_%1", _stamp], _snap, true];

            ["INFO", "audit",
                format ["Daily audit archive created: BO_auditArchive_%1", _stamp]
            ] call BO_fnc_log;

            // Trim archives older than BO_auditArchiveDays. Without this,
            // saveGame persists every BO_auditArchive_* server variable
            // forever -- profile namespace and save payload both grow
            // unbounded.
            private _maxAge = [BO_auditArchiveDays, 7] select (isNil "BO_auditArchiveDays");
            if (_maxAge > 0) then {
                // Compute today's date as a comparable YYYYMMDD integer,
                // then subtract _maxAge days using BIS_fnc_addDaytime to
                // get correct month/year rollover.
                private _todayDate = [date select 0, date select 1, date select 2, 0, 0];
                private _cutoff = [_todayDate, -24 * _maxAge] call BIS_fnc_addDaytime;
                _cutoff params ["_cYear", "_cMonth", "_cDay"];
                private _cutoffNum = (_cYear * 10000) + (_cMonth * 100) + _cDay;

                // Find every BO_auditArchive_* key on the server namespace.
                // Length of "BO_auditArchive_" prefix is 16 chars; date
                // suffix follows in YYYY-MM-DD form.
                private _archiveKeys = (allVariables server) select {
                    (toLower (_x select [0, 16])) isEqualTo "bo_auditarchive_"
                };
                {
                    private _key = _x;
                    private _suffix = _key select [16];
                    private _parts = _suffix splitString "-";
                    if (count _parts == 3) then {
                        private _yy = parseNumber (_parts select 0);
                        private _mm = parseNumber (_parts select 1);
                        private _dd = parseNumber (_parts select 2);
                        private _keyNum = (_yy * 10000) + (_mm * 100) + _dd;
                        if (_keyNum < _cutoffNum) then {
                            server setVariable [_key, nil, true];
                            ["INFO", "audit",
                                format ["Pruned stale archive %1 (older than %2d)", _key, _maxAge]
                            ] call BO_fnc_log;
                        };
                    };
                } forEach _archiveKeys;
            };
        },
        60,
        []
    ] call CBA_fnc_addPerFrameHandler;
};

private _logMsg = format ["Audit log initialized with %1 categories", count _categories];
BO_LOG_INFO("init", _logMsg);
