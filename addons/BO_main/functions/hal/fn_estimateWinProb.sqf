#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_estimateWinProb
 *
 * V2 five-term O(1) estimator (build doc section 8 -- deliberately NOT
 * a research project: no LOS sampling, no knowsAbout density).
 *
 *   winProb = 0.5
 *     + 0.2  * (friendly - enemy) / max(friendly, enemy)
 *     + 0.15 * (AT in group AND enemy has vehicle)
 *     - 0.15 * (enemy has AT AND group has vehicle)
 *     + 0.1  * (friendly air within 3km)
 *   clamped 0..1
 *
 * Params: 0: GROUP, 1: ARRAY contact pos
 * Returns: NUMBER 0..1
 */

SERVER_ONLY;
params [["_grp", grpNull, [grpNull]], ["_pos", [0,0,0], [[]]]];
if (isNull _grp) exitWith { 0 };

private _friendly = { alive _x } count (units _grp);
if (_friendly isEqualTo 0) exitWith { 0 };

private _enemies = (_pos nearEntities [["CAManBase"], 500]) select {
    alive _x && { side group _x isEqualTo independent } && { !captive _x }
};
private _enemyVeh = (_pos nearEntities [["LandVehicle"], 500]) select {
    alive _x && { side group _x isEqualTo independent } && { count crew _x > 0 }
};
private _enemy = (count _enemies) max 1;

private _grpHasAT  = ((units _grp) findIf { alive _x && { secondaryWeapon _x isNotEqualTo "" } }) != -1;
private _grpHasVeh = ((units _grp) findIf { alive _x && { vehicle _x isNotEqualTo _x } }) != -1;
private _enemyHasAT = (_enemies findIf { secondaryWeapon _x isNotEqualTo "" }) != -1;

private _airNear = ((_pos nearEntities [["Air"], 3000]) findIf {
    alive _x && { side _x isEqualTo west } && { count crew _x > 0 }
}) != -1;

private _p = 0.5
    + 0.2 * ((_friendly - _enemy) / ((_friendly max _enemy) max 1))
    + 0.15 * ([0, 1] select (_grpHasAT && { count _enemyVeh > 0 }))
    - 0.15 * ([0, 1] select (_enemyHasAT && _grpHasVeh))
    + 0.1 * ([0, 1] select _airNear);

_p max 0 min 1
