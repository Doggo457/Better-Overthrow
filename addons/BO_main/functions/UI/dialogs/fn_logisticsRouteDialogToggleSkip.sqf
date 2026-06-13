#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsRouteDialogToggleSkip
 *
 * Flip the skip-if-source-empty flag on the route dialog and update
 * the toggle button's label.
 */

private _disp = uiNamespace getVariable ["BO_dialog_logisticsRoute", displayNull];
if (isNull _disp) exitWith {};

private _cur = _disp getVariable ["BO_routeSkipIfEmpty", true];
private _next = !_cur;
_disp setVariable ["BO_routeSkipIfEmpty", _next];

(_disp displayCtrl 1623) ctrlSetText (
    if (_next) then { "Skip if source empty: ON" } else { "Skip if source empty: OFF" }
);
