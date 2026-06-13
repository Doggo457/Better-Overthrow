#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_supplyRun
 *
 * Execute ONE supply flight (scheduled by fn_supplyInit; runs in a
 * scheduled context -- it sleeps).
 *
 * PLANE leg (+1000): needs a NATO-held AIRFIELD matched to an engine
 * airport id (landAt). Spawns at the map edge, flies in, lands; the
 * grant fires only once it has come to a STOP on the runway. Then it
 * takes off, flies to the edge and deletes. Destroyed at ANY point
 * before the stop: no resources.
 *
 * HELI leg (+200): used when no airfield is held or the modset has no
 * cargo plane. Same rules at a random held base.
 *
 * Both leave wreckage where they die -- world state, plus a minor
 * notification each way so interdiction is a readable game loop.
 */

SERVER_ONLY;
if (BO_supplyActive) exitWith {};
BO_supplyActive = true;

private _center = [worldSize / 2, worldSize / 2, 0];
private _abandoned = server getVariable ["NATOabandoned", []];

// ---- pick the leg -----------------------------------------------------
private _airfield = [];   // [enginePadIdx, padPos] when plane leg is on
private _planeCls = missionNamespace getVariable ["BO_supplyPlaneClass", ""];
if (_planeCls isNotEqualTo "") then {
    private _heldPorts = (missionNamespace getVariable ["OT_airportData", []]) select {
        !((_x select 1) in _abandoned)
    };
    {
        _x params ["_apPos", "_apName"];
        if (_airfield isEqualTo []) then {
            {
                _x params ["_idx", "_ils"];
                if (_airfield isEqualTo [] && {_ils isNotEqualTo []}
                    && {(_ils distance2D _apPos) < 1800}) then {
                    _airfield = [_idx, +_ils];
                };
            } forEach (missionNamespace getVariable ["BO_supplyAirports", []]);
        };
    } forEach _heldPorts;
};

private _isPlane = _airfield isNotEqualTo [];
private _amount = [200, 1000] select _isPlane;

// Heli destination: random held base.
private _dest = if (_isPlane) then { _airfield select 1 } else {
    private _held = ((missionNamespace getVariable ["OT_objectiveData", []])
        + (missionNamespace getVariable ["OT_airportData", []])) select {
        !((_x select 1) in _abandoned)
    };
    if (_held isEqualTo []) exitWith { [] };
    (selectRandom _held) select 0
};
if (_dest isEqualTo []) exitWith { BO_supplyActive = false };

private _cls = if (_isPlane) then { _planeCls } else {
    private _c = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport_Large", ""];
    if (_c isEqualTo "") then {
        private _arr = missionNamespace getVariable ["OT_NATO_Vehicle_AirTransport", []];
        _c = if (_arr isEqualType "") then { _arr } else { _arr param [0, ""] };
    };
    _c
};
if (_cls isEqualTo "") exitWith { BO_supplyActive = false };

// ---- inbound -----------------------------------------------------------
private _dirOut = _center getDir _dest;
private _edge = _center getPos [(worldSize * 0.72), _dirOut];
_edge set [2, 400];

private _air = createVehicle [_cls, _edge, [], 0, "FLY"];
_air flyInHeight ([150, 350] select _isPlane);
_air setVariable ["BO_HAL_unit", true, false];
_air setVariable ["BO_supplyBird", true, true];
createVehicleCrew _air;
private _crew = group ((crew _air) param [0, objNull]);
if (isNull _crew) exitWith { deleteVehicle _air; BO_supplyActive = false };
_crew setVariable ["BO_HAL_op", -1, false];
[_crew, false] call BO_HAL_fnc_dressGroup;
_crew setBehaviour "CARELESS";
_crew setCombatMode "BLUE";

private _pad = objNull;
if (_isPlane) then {
    _air landAt (_airfield select 0);
} else {
    private _lz = _dest findEmptyPosition [10, 80, _cls];
    if (_lz isEqualTo []) then { _lz = +_dest };
    _pad = createVehicle ["Land_HelipadEmpty_F", _lz, [], 0, "CAN_COLLIDE"];
    private _wp = _crew addWaypoint [_lz, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 100;
    _air land "LAND";
};

("NATO supply flight inbound -- intercept it before it lands")
    remoteExec ["OT_fnc_notifyMinor", 0, false];
["supply_inbound", [_amount, _isPlane]] call BO_HAL_fnc_aar;

// ---- the race ----------------------------------------------------------
private _granted = false;
private _t0 = serverTime;
while { alive _air && {(serverTime - _t0) < 1500} } do {
    if (!_granted
        && {isTouchingGround _air}
        && {speed _air < 2}
        && {(_air distance2D _dest) < ([300, 1200] select _isPlane)}) exitWith {
        _granted = true;
    };
    // Heli: re-issue land while hovering shy of the pad.
    if (!_isPlane && {(serverTime - _t0) > 240} && {!isTouchingGround _air}
        && {(_air distance2D _dest) < 300}) then {
        _air land "LAND";
    };
    sleep 5;
};

if (!alive _air) exitWith {
    ("NATO supply flight DESTROYED -- the shipment is lost")
        remoteExec ["OT_fnc_notifyGood", 0, false];
    ["supply_destroyed", [_amount]] call BO_HAL_fnc_aar;
    if (!isNull _pad) then { deleteVehicle _pad };
    BO_supplyActive = false;
};

if (_granted) then {
    server setVariable ["NATOresources",
        (server getVariable ["NATOresources", 0]) + _amount, true];
    (format ["NATO supply delivered (+%1 resources)", _amount])
        remoteExec ["OT_fnc_notifyMinor", 0, false];
    ["supply_delivered", [_amount]] call BO_HAL_fnc_aar;
    sleep 25;  // unload beat, then wheels-up
} else {
    ["supply_timeout", [_amount]] call BO_HAL_fnc_aar;
};

// ---- outbound + cleanup -------------------------------------------------
if (alive _air) then {
    _air engineOn true;
    _air flyInHeight ([150, 350] select _isPlane);
    private _exit = _center getPos [(worldSize * 0.75), _dirOut + 150];
    _exit set [2, 400];
    while { count waypoints _crew > 0 } do { deleteWaypoint [_crew, 0] };
    private _wpo = _crew addWaypoint [_exit, 0];
    _wpo setWaypointType "MOVE";
    _wpo setWaypointCompletionRadius 400;

    private _t1 = serverTime;
    waitUntil {
        sleep 10;
        !alive _air
        || {(_air distance2D _center) > (worldSize * 0.68)}
        || {(serverTime - _t1) > 900}
    };
};
// Clean exit only for a LIVING bird at the edge -- a kill after the
// grant leaves wreck + crew bodies as world loot (no corpse-vanishing
// in front of the shooter).
if (alive _air) then {
    { if (!isNull _x) then { deleteVehicle _x } } forEach (crew _air);
    deleteVehicle _air;
    if (!isNull _crew) then { deleteGroup _crew };
};
if (!isNull _pad) then { deleteVehicle _pad };
BO_supplyActive = false;
