#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_log
 *
 * Single entry point for all Better Overthrow log output. Writes a
 * standardized line to the Arma RPT file and routes ERROR-level
 * messages to systemChat for admin visibility.
 *
 * Format written to RPT:
 *   [BO][<level>][<subsystem>][<timestamp>] <message>
 *
 * Filtering: a global BO_logLevel int (0=DEBUG, 1=INFO, 2=WARN,
 * 3=ERROR) gates everything below the threshold. The macros in
 * log_macros.hpp short-circuit before calling this function so the
 * cost when filtered is just one integer comparison.
 *
 * Params:
 *   0: STRING - level   ("DEBUG" / "INFO" / "WARN" / "ERROR")
 *   1: STRING - subsystem ("team" / "logistics" / etc.)
 *   2: STRING - message
 *
 * Returns: nothing.
 *
 * Side effects:
 *   - diag_log writes one line to the RPT
 *   - ERROR level mirrors to systemChat for any admin online
 */

params [
    ["_level", "INFO", [""]],
    ["_subsystem", "general", [""]],
    ["_message", "", [""]]
];

// Filter by configured threshold. BO_logLevel is set by
// BO_fnc_preInit from the bo_log_level mission param.
private _levelInt = switch (_level) do {
    case "DEBUG": { 0 };
    case "INFO":  { 1 };
    case "WARN":  { 2 };
    case "ERROR": { 3 };
    default { 1 };
};
private _threshold = missionNamespace getVariable ["BO_logLevel", 1];

// ERROR always passes the threshold so true crashes never get
// silently dropped because someone set bo_log_level above 3.
if (_levelInt < _threshold && _level isNotEqualTo "ERROR") exitWith {};

// Subsystem allowlist support. Empty list = all subsystems pass.
// Set via bo_log_subsystems param at preInit.
private _allowlist = missionNamespace getVariable ["BO_logSubsystems", []];
if (_allowlist isNotEqualTo [] && !(_subsystem in _allowlist)) exitWith {};

// Compose the line. We don't use systemTime/date in the formatted
// timestamp because RPT already carries a per-line wall-clock stamp;
// our timestamp here is in-game date which is what players care about
// when correlating to mission events.
private _stamp = [] call BO_fnc_formatTimestamp;
private _line = format ["[BO][%1][%2][%3] %4", _level, _subsystem, _stamp, _message];

diag_log _line;

// ERROR-level lines additionally surface to the admin via the
// standard BO notify channel. RULE 0: never use systemChat -- that
// broadcasts to every player. serverCommandAvailable "#shutdown" is
// the canonical admin-presence check (logged-in admin only).
if (_level isEqualTo "ERROR" && hasInterface && {!isNull (findDisplay 46)} && {serverCommandAvailable "#shutdown"}) then {
    _line call OT_fnc_notifyBad;
};
