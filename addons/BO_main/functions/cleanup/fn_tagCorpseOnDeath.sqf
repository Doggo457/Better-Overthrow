#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_tagCorpseOnDeath
 *
 * Set the BO_deathTime and BO_lastNearPlayer variables on a freshly
 * killed unit. These power the proximity-based decay timer in the
 * sweep loop.
 *
 * Skipped for:
 *   - players (never auto-cleaned)
 *   - mission-flagged corpses (BO_exempt = true)
 *   - units that already have a death timestamp (idempotency)
 *
 * Params:
 *   0: OBJECT - dead unit
 */

params [["_unit", objNull, [objNull]]];

if (isNull _unit) exitWith {};
if (isPlayer _unit) exitWith {};
if (_unit getVariable ["BO_exempt", false]) exitWith {};
if (!isNil { _unit getVariable "BO_deathTime" }) exitWith {};

_unit setVariable ["BO_deathTime", diag_tickTime, false];
_unit setVariable ["BO_lastNearPlayer", diag_tickTime, false];
