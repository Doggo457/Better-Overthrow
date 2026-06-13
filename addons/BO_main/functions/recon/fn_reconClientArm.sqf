#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconClientArm
 *
 * Client-only. Receives [scope, scopeKey, expireServerTime] from the
 * server's reconPurchase handler (or from reconRebuildClient on
 * JIP/load/respawn). Scans BLUFOR entities in the requested scope,
 * reveals them to the resistance via OT_fnc_revealToResistance, drops
 * local map markers per target, and installs a CBA per-frame handler
 * that fades the markers + renders a corner HUD countdown until expiry.
 *
 * Markers are LOCAL (createMarkerLocal) -- other players can't see
 * intel they didn't pay for.
 *
 * Params:
 *   0: STRING - scope    ("TOWN" | "REGION" | "MAP")
 *   1: STRING - scopeKey (town/objective/airport name, "" for MAP)
 *   2: NUMBER - expireServerTime (serverTime at which to tear down)
 */

if (!hasInterface) exitWith {};

params [
    ["_scope", "TOWN", [""]],
    ["_scopeKey", "", [""]],
    ["_expireServerTime", 0, [0]]
];

// Resolve scan centre + radius.
private _center = [0, 0, 0];
private _radius = 0;
call {
    if (_scope isEqualTo "TOWN") exitWith {
        {
            _x params ["_p", "_n"];
            if (_n isEqualTo _scopeKey) exitWith { _center = _p };
        } forEach OT_townData;
        _radius = 600;
    };
    if (_scope isEqualTo "REGION") exitWith {
        {
            _x params ["_p", "_n"];
            if (_n isEqualTo _scopeKey) exitWith { _center = _p };
        } forEach (OT_objectiveData + OT_airportData);
        _radius = 1500;
    };
    _center = [worldSize / 2, worldSize / 2, 0];
    _radius = worldSize;
};

// Collect targets: men + vehicles + air + ships, BLUFOR, in range.
private _candidates = (allUnits + vehicles) select {
    (alive _x)
    && {(side _x) isEqualTo blufor}
    && {(_x distance2D _center) < _radius}
    && {
        (_x isKindOf "CAManBase")
        || (_x isKindOf "Car")
        || (_x isKindOf "Tank")
        || (_x isKindOf "Air")
        || (_x isKindOf "Ship")
    }
};
if (count _candidates > 200) then { _candidates resize 200 };

// NOTE: reveal pass runs server-side in BO_fnc_reconPurchase --
// `groups independent` is server-local, so calling OT_fnc_revealToResistance
// from the client would be a no-op against the actual resistance AI.
// The client-local _candidates list is used only for marker placement.

// Place local map markers, one per target. Use a monotonic counter +
// random tail so two recons in the same second don't collide on the
// floor-tickTime stamp.
private _markers = [];
BO_reconMarkerCounter = (missionNamespace getVariable ["BO_reconMarkerCounter", 0]) + 1;
missionNamespace setVariable ["BO_reconMarkerCounter", BO_reconMarkerCounter];
private _stamp = format ["%1_%2_%3", _scope, BO_reconMarkerCounter, floor (random 1e6)];
{
    private _mid = format ["bo_recon_%1_%2", _stamp, _forEachIndex];
    createMarkerLocal [_mid, getPosWorld _x];
    private _type = if (_x isKindOf "CAManBase") then { "mil_dot" } else { "mil_triangle" };
    _mid setMarkerTypeLocal _type;
    _mid setMarkerColorLocal "ColorBLUFOR";
    _mid setMarkerTextLocal "NATO";
    _mid setMarkerAlphaLocal 1.0;
    _markers pushBack _mid;
} forEach _candidates;

// Build HUD ctrlGroup on the main display (46) -- corner countdown.
// Use a monotonic counter for IDC and slot so partial expiry doesn't
// cause overlapping IDC/y-slots with still-living entries.
disableSerialization;
private _disp = findDisplay 46;
BO_reconHudCounter = (missionNamespace getVariable ["BO_reconHudCounter", 0]) + 1;
missionNamespace setVariable ["BO_reconHudCounter", BO_reconHudCounter];
private _hudIdc = 9100 + BO_reconHudCounter;
private _hudSlot = BO_reconHudCounter mod 6;
private _txt = controlNull;
if (!isNull _disp) then {
    private _c = _disp ctrlCreate ["RscStructuredText", _hudIdc];
    _c ctrlSetPosition [
        0.78 * safeZoneW + safeZoneX,
        (0.10 + 0.04 * _hudSlot) * safeZoneH + safeZoneY,
        0.20 * safeZoneW,
        0.04 * safeZoneH
    ];
    _c ctrlSetBackgroundColor [0, 0, 0, 0.4];
    _c ctrlCommit 0;
    _txt = _c;
};

private _durMin = missionNamespace getVariable ["BO_reconDurationMinutes", 10];
private _fullDur = _durMin * 60;

// Per-frame fader + countdown. PFH closure captures the markers/HUD
// directly so a future expire-sweep can identify this entry by scope/key.
private _pfh = [{
    params ["_args", "_id"];
    _args params ["_expire", "_markers", "_txt", "_scope", "_key", "_fullDur"];
    private _remaining = (_expire - serverTime) max 0;
    if (_remaining <= 0) exitWith {
        { deleteMarkerLocal _x } forEach _markers;
        if (!isNull _txt) then { ctrlDelete _txt };
        [_id] call CBA_fnc_removePerFrameHandler;
        "Recon flight expired" call OT_fnc_notifyMinor;
        private _state = missionNamespace getVariable ["BO_reconClientActive", []];
        _state = _state select {
            !((_x select 0) isEqualTo _scope && {(_x select 1) isEqualTo _key})
        };
        missionNamespace setVariable ["BO_reconClientActive", _state];
    };
    private _alpha = ((_remaining / _fullDur) max 0.15) min 1.0;
    { _x setMarkerAlphaLocal _alpha } forEach _markers;
    if (!isNull _txt) then {
        private _mins = floor (_remaining / 60);
        private _secs = floor (_remaining mod 60);
        private _secStr = if (_secs < 10) then { format ["0%1", _secs] } else { str _secs };
        private _label = if (_key isEqualTo "") then { _scope } else { format ["%1 %2", _scope, _key] };
        private _line = format [
            "<t size='0.9' align='center' color='#88ccff'>Recon: %1 (%2:%3)</t>",
            _label, _mins, _secStr
        ];
        _txt ctrlSetStructuredText parseText _line;
    };
}, 1.0, [_expireServerTime, _markers, _txt, _scope, _scopeKey, _fullDur]] call CBA_fnc_addPerFrameHandler;

private _state = missionNamespace getVariable ["BO_reconClientActive", []];
_state pushBack [_scope, _scopeKey, _expireServerTime, _markers, _pfh, _txt];
missionNamespace setVariable ["BO_reconClientActive", _state];

private _notifyMsg = format ["Recon active: %1 unit(s) revealed", count _candidates];
_notifyMsg call OT_fnc_notifyGood;
