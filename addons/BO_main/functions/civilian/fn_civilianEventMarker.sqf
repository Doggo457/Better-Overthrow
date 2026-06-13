#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_civilianEventMarker
 *
 * Local-client helper. Creates (or refreshes) a map marker pointing
 * at an active informant. Called via remoteExec from spawnInformant
 * (broadcast + JIP-true) and from civilianEventOnConnect (targeted
 * at the connecting client).
 *
 * Idempotent on _markerId: existing marker is deleted first so the
 * call also serves as a "refresh position" path.
 *
 * Params:
 *   0: STRING - marker id (must be unique per event)
 *   1: ARRAY  - world position
 *   2: STRING - town name (display label)
 */

params [["_markerId", "", [""]], ["_pos", [0,0,0], [[]]], ["_town", "", [""]]];

if (!hasInterface) exitWith {};
if (_markerId isEqualTo "") exitWith {};

if ((allMapMarkers findIf {_x isEqualTo _markerId}) >= 0) then {
    deleteMarkerLocal _markerId;
};

private _mrk = createMarkerLocal [_markerId, _pos];
_mrk setMarkerTypeLocal "hd_dot";
_mrk setMarkerColorLocal "ColorBlue";
private _label = format ["Informant: %1", _town];
_mrk setMarkerTextLocal _label;
_mrk setMarkerAlphaLocal 0.9;

private _tracked = missionNamespace getVariable ["BO_clientInformantMarkers", []];
_tracked pushBackUnique _markerId;
missionNamespace setVariable ["BO_clientInformantMarkers", _tracked];
