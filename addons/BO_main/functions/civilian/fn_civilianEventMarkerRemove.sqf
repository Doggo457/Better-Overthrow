#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventMarkerRemove
 *
 * Local-client helper. Deletes the named informant marker if it
 * exists and unhooks it from the per-client tracker.
 *
 * Called via remoteExec from BO_fnc_civilianEventCleanup.
 *
 * Params:
 *   0: STRING - marker id
 */

params [["_markerId", "", [""]]];

if (!hasInterface) exitWith {};
if (_markerId isEqualTo "") exitWith {};

if ((allMapMarkers findIf {_x isEqualTo _markerId}) >= 0) then {
    deleteMarkerLocal _markerId;
};

private _tracked = missionNamespace getVariable ["BO_clientInformantMarkers", []];
_tracked = _tracked - [_markerId];
missionNamespace setVariable ["BO_clientInformantMarkers", _tracked];
