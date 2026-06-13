/*
 * log_macros.hpp
 *
 * Fixed-arity wrappers around BO_fnc_log. Each macro takes exactly
 * two args: subsystem and a pre-built message string.
 *
 * Why fixed-arity instead of variadic: HEMTT's preprocessor does
 * not support C99 variadic macros (`...` / `__VA_ARGS__`).
 * Warning: the message expression is split on commas OUTSIDE
 * string literals. Commas inside string literals are safe.
 * So an inline `format ["msg %1", _x]` would be torn into multiple
 * args by the trailing `, _x`. Build the message into a local
 * variable first, then pass that single variable to the macro.
 *
 * Call site syntax:
 *   BO_LOG_INFO("subsys", "Plain message");
 *
 *   private _msg = format ["Format msg %1", _x];
 *   BO_LOG_INFO("subsys", _msg);
 *
 *   private _msg = format ["Multi %1 %2 %3", _a, _b, _c];
 *   BO_LOG_INFO("subsys", _msg);
 *
 * Filtering: BO_logLevel is read at runtime. Levels:
 *   0 = DEBUG, 1 = INFO, 2 = WARN, 3 = ERROR.
 * Calls below the threshold short-circuit without paying the
 * call cost. The format cost at call sites is paid unconditionally,
 * which is acceptable — string formatting is cheap relative to the
 * systems that use it.
 */

#ifndef BO_LOG_DEBUG
#define BO_LOG_DEBUG(subsys, msg) \
    if (BO_logLevel <= 0) then { ["DEBUG", subsys, msg] call BO_fnc_log }
#endif

#ifndef BO_LOG_INFO
#define BO_LOG_INFO(subsys, msg) \
    if (BO_logLevel <= 1) then { ["INFO", subsys, msg] call BO_fnc_log }
#endif

#ifndef BO_LOG_WARN
#define BO_LOG_WARN(subsys, msg) \
    if (BO_logLevel <= 2) then { ["WARN", subsys, msg] call BO_fnc_log }
#endif

#ifndef BO_LOG_ERROR
#define BO_LOG_ERROR(subsys, msg) \
    if (BO_logLevel <= 3) then { ["ERROR", subsys, msg] call BO_fnc_log }
#endif
