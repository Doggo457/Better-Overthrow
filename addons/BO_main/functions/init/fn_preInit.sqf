#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_preInit
 *
 * Runs very early in mission init (auto-triggered via the preInit=1
 * attribute in CfgFunctions). Sets up read-only configuration that
 * later functions depend on:
 *
 *   - reads mission params into missionNamespace globals
 *   - initializes namespace placeholders (BO_logLevel, etc.)
 *   - bootstraps the audit log hashmap on the server
 *
 * It does NOT install OT_fnc_ overrides — that happens at postInit,
 * after CfgFunctions has finished populating OT_fnc_ refs.
 *
 * Side effects:
 *   - sets several BO_* globals on missionNamespace
 *   - on server: initializes BO_auditLog hashmap
 *   - writes one INFO line to the RPT signaling init started
 */

// ------------------------------------------------------------------
// Read mission params with sensible defaults.
//
// We read params even on clients; many of these are referenced from
// both sides. Dedicated servers use BIS_fnc_getParamValue, hosted
// servers get the same value through paramsArray.
// ------------------------------------------------------------------
BO_logLevel = (["bo_log_level", 1] call BIS_fnc_getParamValue);
BO_logSubsystems = []; // parsed below if the comma-separated string param is set

BO_auditCapHigh = (["bo_audit_high_cap", 1000] call BIS_fnc_getParamValue);
BO_auditCapMed  = (["bo_audit_med_cap",  500]  call BIS_fnc_getParamValue);
BO_auditCapLow  = (["bo_audit_low_cap",  200]  call BIS_fnc_getParamValue);

BO_auditDailyArchive = ((["bo_audit_daily_archive", 1] call BIS_fnc_getParamValue) isEqualTo 1);
BO_auditArchiveDays  = (["bo_audit_archive_days", 7] call BIS_fnc_getParamValue);

BO_perfMetrics = ((["bo_perf_metrics", 1] call BIS_fnc_getParamValue) isEqualTo 1);

BO_corpseDecaySeconds = (["bo_corpse_decay", 3600] call BIS_fnc_getParamValue);
BO_corpseDecayRadius  = (["bo_corpse_decay_radius", 200] call BIS_fnc_getParamValue);

// NOTE: Initialization of the audit-log container (server var
// "BO_auditLog") moved to BO_fnc_initAuditLog, which is called from
// postInit *after* OT's initServer.sqf has created the `server`
// namespace. preInit runs before initServer.sqf so `server` is still
// undefined here -- referencing it in preInit produced an "Undefined
// variable: server" RPT error every mission load.

// Performance metrics container is missionNamespace-local on every
// machine; not networked, not saved.
BO_perfStore = createHashMap;

// ------------------------------------------------------------------
// Log init started. Use the raw BO_fnc_log call (not the macro)
// because preInit may run before the macro header is parsed in some
// edge cases (function inlining of macros happens at compile time
// and CfgFunctions compilation order is not strictly deterministic).
// ------------------------------------------------------------------
["INFO", "init", format ["Better Overthrow preInit (logLevel=%1, server=%2)", BO_logLevel, isServer]] call BO_fnc_log;
