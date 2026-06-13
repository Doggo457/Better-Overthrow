#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_spawnBusinessWorker
 *
 * Spawner callback for OT's virtualization layer. Registered in
 * BO_fnc_initBusiness via OT_fnc_registerSpawner so it fires when
 * a player enters spawn distance of a placed business.
 *
 * Visible-employee model: the wage tick deducts for the spec'd
 * employee count (4-8 per business type), but only ONE worker NPC
 * is rendered. The rest stay virtual -- they cost cash, not AI
 * budget. Same "1 visible per N virtual" pattern used by other
 * Arma campaign mods to keep CPU costs manageable while still
 * making the business feel inhabited.
 *
 * Idempotent: if a worker already exists for this business (e.g.
 * the OT spawn loop fired twice during a fast player approach),
 * skip the spawn.
 *
 * Server-only -- unit creation is server-auth.
 *
 * Params (passed via OT_fnc_registerSpawner's _params):
 *   0: OBJECT - the business building
 *   1: STRING - business type display name
 */

if (!isServer) exitWith {};

params [["_business", objNull, [objNull]], ["_type", "", [""]]];
if (isNull _business) exitWith {};
if (!alive _business) exitWith {};

// Dedupe: existing worker still alive? Don't spawn a second one.
// Object refs DON'T survive save/load, but on a fresh boot the
// initBusiness path will run before the first spawner fire so the
// var is reliable within a session. On load, we sweep nearby units
// for the BO_businessWorkerFor tag to rebind.
private _existing = _business getVariable ["BO_businessWorker", objNull];
if (!isNull _existing && {alive _existing}) exitWith {};

private _businessPos = getPosATL _business;
{
    if ((_x getVariable ["BO_businessWorkerFor", objNull]) isEqualTo _business && {alive _x}) exitWith {
        _business setVariable ["BO_businessWorker", _x, true];
        _existing = _x;
    };
} forEach (_businessPos nearEntities ["CAManBase", 40]);
if (!isNull _existing) exitWith {};

// Random spawn position within 8m of the building door-ish area.
private _spawnPos = _business getPos [4 + random 4, random 360];

private _grp = createGroup [civilian, true];
_grp setBehaviour "SAFE";

private _worker = _grp createUnit [OT_civType_worker, _spawnPos, [], 0, "NONE"];
_worker setBehaviour "SAFE";

private _identity = call OT_fnc_randomLocalIdentity;
_identity set [1, ""]; // keep worker clothes
[_worker, _identity] call OT_fnc_applyIdentity;

// Tags:
//   notalk            -- OT recruitment check skips this NPC
//   BO_businessWorkerFor -- back-pointer for rebind after load
//   employee          -- mirrors OT shop/business employee mark so
//                        OT cleanup treats this as business staff
_worker setVariable ["notalk", true, true];
_worker setVariable ["BO_businessWorkerFor", _business, true];
_worker setVariable ["employee", _type, true];

// Loiter waypoints: short patrol around the business so the worker
// looks like they're going about their day rather than t-posing.
// Cycle waypoint at the end so the patrol repeats indefinitely.
private _wp1 = _grp addWaypoint [_business getPos [6 + random 4, random 360], 0];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointSpeed "LIMITED";
_wp1 setWaypointCompletionRadius 3;
_wp1 setWaypointTimeout [10, 20, 40];

private _wp2 = _grp addWaypoint [_business getPos [6 + random 4, random 360], 0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointSpeed "LIMITED";
_wp2 setWaypointCompletionRadius 3;
_wp2 setWaypointTimeout [10, 20, 40];

private _wp3 = _grp addWaypoint [_spawnPos, 0];
_wp3 setWaypointType "CYCLE";

_business setVariable ["BO_businessWorker", _worker, true];

// Register the group with OT's spawn tracking so the existing
// despawn-on-player-leaves machinery cleans it up. _params [3] in
// OT_allSpawners is the _spawnid (slot 0 in registerSpawner's
// pushBack); OT_fnc_spawnBusinessEmployees writes the group ref
// back to spawner via this same key.
private _spawnid = _this param [2, ""];
if (_spawnid isNotEqualTo "") then {
    spawner setVariable [_spawnid, (spawner getVariable [_spawnid, []]) + [_grp], false];
};

private _msg = format ["Worker spawned for %1 at %2", _type, mapGridPosition _business];
BO_LOG_DEBUG("business", _msg);
