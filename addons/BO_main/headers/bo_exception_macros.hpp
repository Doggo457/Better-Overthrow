/*
 * bo_exception_macros.hpp
 *
 * Defensive guards used by BO functions.
 *
 *   REQUIRE(cond, msg, exitValue)
 *     Soft guard, logs WARN. Input validation that should fail
 *     gracefully. `msg` must be a plain string expression — pre-format
 *     into a local var if you need interpolation (HEMTT splits macro
 *     args on every comma regardless of paren/bracket nesting).
 *
 *   SERVER_ONLY              — drop out silently on clients.
 *   SERVER_ONLY_RET(value)   — same, with a default return value.
 */

#ifndef BO_EXCEPTION_MACROS_HPP
#define BO_EXCEPTION_MACROS_HPP

#ifndef REQUIRE
#define REQUIRE(cond, msg, exitValue) \
    if (!(cond)) exitWith { \
        ["WARN", "guard", msg] call BO_fnc_log; \
        exitValue \
    }
#endif

#ifndef SERVER_ONLY
#define SERVER_ONLY \
    if (!isServer) exitWith {}
#endif

#ifndef SERVER_ONLY_RET
#define SERVER_ONLY_RET(exitValue) \
    if (!isServer) exitWith { exitValue }
#endif

#endif // BO_EXCEPTION_MACROS_HPP
