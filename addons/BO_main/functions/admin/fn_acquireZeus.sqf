#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_acquireZeus
 *
 * Server-only curator factory for multi-user Zeus. An engine curator
 * module supports exactly ONE assigned player, so the old shared
 * BO_zeusCuratorRestricted meant any second General stole the seat
 * from the first. Each (uid, tier) now gets its own module, cached in
 * BO_zeusRegistry ([[uid, tier, curator], ...], server-local).
 *
 * Tiers:
 *   "restricted" -- high command: empty create tab, Place/Edit/Delete/
 *                   Destroy coefs -1, free waypoints, editable pool =
 *                   independent side only.
 *   "full"       -- admin/host: addon pool cloned from the mission's
 *                   zeusCurator (fallback: every activated addon),
 *                   default coefs, editable pool = everything.
 *
 * The EntityCreated/PlayerDisconnected maintenance handlers live in
 * BO_fnc_initRestrictedZeus.
 *
 * Params: 0: STRING player UID, 1: STRING tier
 * Returns: OBJECT curator (objNull on bad input)
 */

SERVER_ONLY;
params [["_uid", "", [""]], ["_tier", "restricted", [""]]];
if (_uid isEqualTo "") exitWith { objNull };

private _reg = missionNamespace getVariable ["BO_zeusRegistry", []];
private _idx = _reg findIf { (_x select 0) isEqualTo _uid && {(_x select 1) isEqualTo _tier} };
if (_idx >= 0) then {
    private _cur = (_reg select _idx) select 2;
    if (!isNull _cur) exitWith { _cur };
    _reg deleteAt _idx; // stale entry, rebuild below
};

if (isNil "BO_zeusLogicGrp" || {isNull BO_zeusLogicGrp}) then {
    private _center = createCenter sideLogic;
    BO_zeusLogicGrp = createGroup _center;
};

private _cur = BO_zeusLogicGrp createUnit ["ModuleCurator_F", [0, 0, 0], [], 0, "NONE"];

// CRITICAL: a bare createUnit'd ModuleCurator_F is only half a Zeus --
// editor-placed modules run BIS_fnc_moduleCurator, which wires up the
// cost tables, waypoint attribute editing, vision modes and remote
// control. Without it, waypoint options were broken even at full tier.
// Attributes must be set BEFORE the init call; Owner stays "" so the
// module never auto-assigns (zeusAssign owns assignment).
_cur setVariable ["Addons", [0, 3] select (_tier isEqualTo "full")]; // 3 = all addons, 0 = none
_cur setVariable ["Forced", 0];
_cur setVariable ["Owner", ""];
_cur setVariable ["Name", format ["BO_zeus_%1_%2", _tier, _uid]];
_cur setVariable ["ShowNotification", false];
[_cur, [], true] call BIS_fnc_moduleCurator;

if (_tier isEqualTo "full") then {
    _cur addCuratorEditableObjects [(allUnits + vehicles), true];
} else {
    removeAllCuratorAddons _cur; // belt + braces over Addons=0
    _cur setCuratorCoef ["Place", -1];
    _cur setCuratorCoef ["Edit", -1];
    _cur setCuratorCoef ["Delete", -1];
    _cur setCuratorCoef ["Destroy", -1];
    _cur setCuratorWaypointCost 0;
    private _indep = (allUnits + vehicles) select { side _x isEqualTo independent };
    _cur addCuratorEditableObjects [_indep, true];
};

_reg pushBack [_uid, _tier, _cur];
missionNamespace setVariable ["BO_zeusRegistry", _reg];

private _msg = format ["Zeus curator created: uid=%1 tier=%2 (registry=%3)", _uid, _tier, count _reg];
BO_LOG_INFO("admin", _msg);
_cur
