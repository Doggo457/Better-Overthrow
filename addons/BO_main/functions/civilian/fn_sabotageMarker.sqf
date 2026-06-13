#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_sabotageMarker
 *
 * Local-client helper. Places a 24-in-game-hour map-intel marker
 * on the named NATO base. Auto-expires the marker locally via a
 * scheduled deleteMarkerLocal.
 *
 * Called via remoteExec from BO_fnc_pickAndRunSabotage (broadcast +
 * JIP-true) and from BO_fnc_civilianEventOnConnect (targeted at the
 * connecting client for entries still within the 24h window).
 *
 * Params:
 *   0: STRING - base name (must match an existing OT marker name)
 *   1: STRING - effect tag (drives marker label)
 */

params [["_baseName", "", [""]], ["_effect", "", [""]]];

if (!hasInterface) exitWith {};
if (_baseName isEqualTo "") exitWith {};

private _mrkId = format ["BO_sabotage_%1", _baseName];
if ((allMapMarkers findIf {_x isEqualTo _mrkId}) >= 0) then {
    deleteMarkerLocal _mrkId;
};

private _pos = markerPos _baseName;
if (_pos isEqualTo [0,0,0]) exitWith {
    private _msg = format ["sabotageMarker: marker '%1' has zero pos, skipping", _baseName];
    diag_log _msg;
};

private _mrk = createMarkerLocal [_mrkId, _pos];
_mrk setMarkerTypeLocal "mil_warning";
_mrk setMarkerColorLocal "ColorGUER";

private _label = switch (_effect) do {
    case "vehicle_fire":       { "Intel: vehicle fire" };
    case "supply_theft":       { "Intel: supply theft" };
    case "garrison_desertion": { "Intel: desertions" };
    default                    { "Intel: sabotage" };
};
_mrk setMarkerTextLocal _label;
_mrk setMarkerAlphaLocal 0.9;

// Auto-expire after 24 in-game hours.
private _accel = if (isNil "OT_timeMultiplier") then { 1.0 } else { OT_timeMultiplier };
if (_accel <= 0) then { _accel = 1.0 };
private _realSec = (24 * 3600) / _accel;

[{
    params ["_id"];
    if ((allMapMarkers findIf {_x isEqualTo _id}) >= 0) then {
        deleteMarkerLocal _id;
    };
}, [_mrkId], _realSec] call CBA_fnc_waitAndExecute;
