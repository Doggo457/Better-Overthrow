#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsTravelTime
 *
 * Pure calc -- compute travel seconds + per-trip fee + raw distance
 * between two containers. No side effects; safe to call from server,
 * client, or the route-editor dialog's live preview.
 *
 * Reads tunable mission params at call time so admins can adjust
 * truck speed / handling / fee without restarting the mission.
 *
 * Params:
 *   0: OBJECT - source container
 *   1: OBJECT - destination container
 *
 * Returns:
 *   [_travelSec, _feeDollars, _distMeters]
 *   ([-1, -1, -1] if either object is null.)
 */

params [["_src", objNull, [objNull]], ["_dst", objNull, [objNull]]];
if (isNull _src || isNull _dst) exitWith { [-1, -1, -1] };

private _speedKmh = missionNamespace getVariable ["bo_logistics_truck_speed_kmh", 50];
private _handling = missionNamespace getVariable ["bo_logistics_handling_seconds", 60];
private _feeBase  = missionNamespace getVariable ["bo_logistics_fee_base", 10];
private _feePerKm = missionNamespace getVariable ["bo_logistics_fee_per_km", 10];

private _speedMps = _speedKmh / 3.6;
if (_speedMps <= 0) then { _speedMps = 13.89 };

private _distM = (getPosATL _src) distance2D (getPosATL _dst);

private _travelSec = (_distM / _speedMps) + (2 * _handling);
private _fee = round (_feeBase + (_distM / 1000) * _feePerKm);

[_travelSec, _fee, _distM]
