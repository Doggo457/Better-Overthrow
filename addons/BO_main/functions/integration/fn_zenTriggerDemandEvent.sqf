#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_zenTriggerDemandEvent
 *
 * Zen module: force a world demand event at the nearest town. Combo
 * picks the event type from BO_eventCatalog. Adds an entry to
 * BO_activeWorldEvents directly so the existing tick / multiplier
 * lookup picks it up immediately.
 *
 * Params (Zen module signature):
 *   0: ARRAY  - placement position
 *   1: OBJECT - module logic
 */

params [["_position", [0,0,0], [[]]], ["_logic", objNull, [objNull]]];
deleteVehicle _logic;

private _town = _position call OT_fnc_nearestTown;
if (_town isEqualTo "") exitWith {
    "No nearest town -- module placed too far from any town" call OT_fnc_notifyBad;
};

private _catalog = if (isNil "BO_eventCatalog") then { [] } else { BO_eventCatalog };
if (_catalog isEqualTo []) exitWith {
    "World events catalog is empty (system disabled?)" call OT_fnc_notifyBad;
};

private _types  = _catalog apply { _x select 0 };
private _labels = _catalog apply { _x select 1 };

[
    format ["Trigger Demand Event at %1", _town],
    [
        ["COMBO", "Event type:", [_types, _labels, 0]]
    ],
    {
        params ["_result", "_args"];
        _args params ["_town"];
        private _type = _result # 0;

        private _spec = [];
        {
            if ((_x select 0) isEqualTo _type) exitWith { _spec = _x };
        } forEach BO_eventCatalog;
        if (_spec isEqualTo []) exitWith {};
        _spec params ["", "_dispName", "_items", "_mulRange"];

        private _mulCap = (missionNamespace getVariable ["bo_event_multiplier_max_cached", 200]) / 100;
        private _mul = ((_mulRange select 0) + random ((_mulRange select 1) - (_mulRange select 0))) min _mulCap;
        _mul = ((_mul * 100) / 100); // round-trip to clean .0
        private _now = +date;
        private _dur = missionNamespace getVariable ["bo_event_duration_days_cached", 2];
        private _end = [_now, _dur * 24] call BIS_fnc_addDaytime;
        private _eid = format ["zen-%1-%2", _town, diag_tickTime];

        private _active = server getVariable ["BO_activeWorldEvents", []];
        _active pushBack [_town, _type, _items, _mulRange, _now, _mul, _eid, _end];
        server setVariable ["BO_activeWorldEvents", _active, true];

        // Marker.
        private _mk = format ["bo_evt_%1", _eid];
        deleteMarker _mk;
        private _posTown = server getVariable _town;
        createMarker [_mk, _posTown];
        _mk setMarkerType "ot_Shop";
        _mk setMarkerSize [0.6, 0.6];
        _mk setMarkerColor "ColorYellow";
        _mk setMarkerText (format ["!%1", _dispName]);

        private _msg = format ["Zeus triggered demand event '%1' at %2 (x%3)", _dispName, _town, _mul];
        _msg call OT_fnc_notifyMinor;
        [AUDIT_EVENTS, _msg, [_town, _type, _mul, _eid], "", ""] call BO_fnc_auditServer;
    },
    {},
    [_town]
] call zen_dialog_fnc_create;
