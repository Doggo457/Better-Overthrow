// =====================================================================
// script_macros.hpp -- merged from OT's original + BO additions
//
// Originally OT shipped with `#include "\x\cba\addons\main\script_macros_common.hpp"`
// at the top. We don't have CBA's source tree at build time; the only
// compile-time things OT borrowed were a couple of stringification
// helpers, redeclared below. Runtime CBA_fnc_* calls are unaffected.
// =====================================================================

#ifndef SCRIPT_MACROS_HPP
#define SCRIPT_MACROS_HPP

// ---------------------------------------------------------------------
// Stringification / array helpers (CBA-equivalent stubs).
// QUOTE expands its arg first, then stringifies, via the two-stage
// indirection -- a single-stage `#var` stringifies the token name
// instead of the expanded value.
// ---------------------------------------------------------------------
#define _BO_STRINGIFY(var) #var
#define QUOTE(var) _BO_STRINGIFY(var)
#define ARR_2(ARG1,ARG2) ARG1,ARG2
#define ARR_3(ARG1,ARG2,ARG3) ARG1,ARG2,ARG3
#define ARR_4(ARG1,ARG2,ARG3,ARG4) ARG1,ARG2,ARG3,ARG4

// ---------------------------------------------------------------------
// BIS TransportItems / TransportMagazines / TransportWeapons helpers.
// Each expands to a complete class declaration including the trailing
// semicolon. Call sites use them as statements:
//   class TransportItems { MACRO_ADDITEM(SomeItem,1) };
// ---------------------------------------------------------------------
#define MACRO_ADDITEM(ITEM,COUNT) \
    class _xx_##ITEM { \
        name = #ITEM; \
        count = COUNT; \
    };

#define MACRO_ADDMAGAZINE(MAGAZINE,COUNT) \
    class _xx_##MAGAZINE { \
        magazine = #MAGAZINE; \
        count = COUNT; \
    };

#define MACRO_ADDWEAPON(WEAPON,COUNT) \
    class _xx_##WEAPON { \
        weapon = #WEAPON; \
        count = COUNT; \
    };

#define MACRO_ADDBACKPACK(BACKPACK,COUNT) \
    class _xx_##BACKPACK { \
        backpack = #BACKPACK; \
        count = COUNT; \
    };

// ---------------------------------------------------------------------
// OT-flavor FUNC helpers and tunables.
// ---------------------------------------------------------------------
#ifndef OT_PFUNC
    #define OT_PFUNC(var) _##FUNC(var)
#endif

#ifndef OT_FUNC
    #define OT_FUNC(var) ##FUNC(var)
#endif

#ifndef OT_VALID_LOOT_CONTAINERS
    #define OT_VALID_LOOT_CONTAINERS ["Car", "ReammoBox_F", "Air", "Ship"]
#endif

#ifndef OT_MAX_WAIT_TIME
    #define OT_MAX_WAIT_TIME 120
#endif

#ifndef OT_TARGET_PRECISION_VCLOSE
    #define OT_TARGET_PRECISION_VCLOSE 10
#endif
#ifndef OT_TARGET_PRECISION_CLOSE
    #define OT_TARGET_PRECISION_CLOSE 20
#endif
#ifndef OT_TARGET_PRECISION_SHORT
    #define OT_TARGET_PRECISION_SHORT 100
#endif
#ifndef OT_TARGET_PRECISION_VNEAR
    #define OT_TARGET_PRECISION_VNEAR 200
#endif
#ifndef OT_TARGET_PRECISION_NEAR
    #define OT_TARGET_PRECISION_NEAR 250
#endif

// ---------------------------------------------------------------------
// BO additions: REQUIRE / REQUIRE_HARD / SERVER_ONLY guards and the
// BO_LOG_* family of logging macros.
// ---------------------------------------------------------------------
#include "exception_macros.hpp"
#include "bo_exception_macros.hpp"
#include "log_macros.hpp"

// Audit category constants -- used by BO_fnc_audit call sites.
// Keeping these as macros prevents typos that would split events
// across "atm" and "Atm" buckets.
#define AUDIT_ATM       "atm"
#define AUDIT_MISSION   "mission"
#define AUDIT_SAVE      "save"
#define AUDIT_ADMIN     "admin"
#define AUDIT_PRICING   "pricing"
#define AUDIT_GARBAGE   "garbage"
#define AUDIT_LOGISTICS "logistics"
#define AUDIT_GARAGE    "garage"
#define AUDIT_INTEL     "intel"
#define AUDIT_ARTILLERY "artillery"
#define AUDIT_CIVILIAN  "civilian"
#define AUDIT_EVENTS    "events"

#define BO_REWARD_BANK   "BANK"
#define BO_REWARD_MONEY  "MONEY"

#endif // SCRIPT_MACROS_HPP
