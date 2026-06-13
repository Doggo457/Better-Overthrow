#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_discoveryEllipse
 *
 * Search-ellipse marker (build doc section 10): players only see HAL's
 * search pattern when they've BOUGHT intel -- gated on the existing
 * BO_activeRecon purchases. Major axis sqrt(silentTicks) * 800m,
 * oriented along the last-known heading. Markers are world state, not
 * notifications (addendum no-notifications rule).
 */

SERVER_ONLY;

private _mk = "BO_HAL_searchEllipse";
private _silent = server getVariable ["BO_HAL_silentTicks", 0];

if (_silent < 2
    || {BO_HAL_lastKnown isEqualTo []}
    || {(server getVariable ["BO_activeRecon", []]) isEqualTo []}) exitWith {
    deleteMarker _mk;
};

BO_HAL_lastKnown params ["_pos", "_t", "_hdg"];

deleteMarker _mk;
createMarker [_mk, _pos];
_mk setMarkerShape "ELLIPSE";
_mk setMarkerBrush "Border";
_mk setMarkerColor "ColorOPFOR";
_mk setMarkerDir _hdg;
_mk setMarkerSize [(sqrt _silent) * 800, (sqrt _silent) * 480];
_mk setMarkerAlpha 0.5;
