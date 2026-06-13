#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_factoryQueueClearTarget
 *
 * Server-auth: empty _factory's BO_queue.
 *
 * Params:
 *   0: OBJECT - factory
 */

SERVER_ONLY;

params [["_factory", objNull, [objNull]]];
if (isNull _factory) exitWith {};

_factory setVariable ["BO_queue", [], true];
