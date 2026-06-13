#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_logisticsSetRole
 *
 * Tag (or untag) a cargo container for the logistics network.
 * Called from the ACE Main Action handlers on the container.
 *
 * Variables set with broadcast (third arg `true`) so they persist
 * across save/load and are visible to other clients (route editor
 * combo boxes enumerate tagged containers across the world).
 *
 * BO_logisticsContainerId is the persistent key the routes table
 * uses to refer to the container. Generated once on first tag and
 * never reused, so routes don't end up pointing at the wrong
 * container if a player clears and re-tags an object.
 *
 * Params:
 *   0: OBJECT - container
 *   1: STRING - "SOURCE" | "DEST" | "" (empty clears the role)
 *   2: STRING - human label (ignored when clearing)
 */

params [
    ["_obj",   objNull, [objNull]],
    ["_role",  "",      [""]],
    ["_label", "",      [""]]
];

if (isNull _obj) exitWith {};

if (_role isEqualTo "") then {
    _obj setVariable ["BO_logisticsRole",        nil, true];
    _obj setVariable ["BO_logisticsLabel",       nil, true];
    _obj setVariable ["BO_logisticsOwner",       nil, true];
    _obj setVariable ["BO_logisticsContainerId", nil, true];

    // Drop the force-save flag too -- without it, the OT save filter
    // will stop persisting the container if it was otherwise unowned,
    // which is the right behavior for a cleared container.
    _obj setVariable ["OT_forceSaveUnowned", nil, true];

    [AUDIT_MISSION, "Logistics: container role cleared"] call BO_fnc_audit;
    "Container removed from logistics network" call OT_fnc_notifyMinor;
} else {
    private _id = _obj getVariable ["BO_logisticsContainerId", ""];
    if (_id isEqualTo "") then {
        _id = format ["c_%1_%2", round diag_tickTime, round (random 999999)];
        _obj setVariable ["BO_logisticsContainerId", _id, true];
    };

    _obj setVariable ["BO_logisticsRole",  _role,                  true];
    _obj setVariable ["BO_logisticsLabel", _label,                 true];
    _obj setVariable ["BO_logisticsOwner", getPlayerUID player,    true];

    // OT's save filter skips containers that don't have an owner.
    // The OT spawn ammobox + a lot of mission-placed crates are
    // unowned -- without this flag they'd be dropped at save time
    // and the tag wouldn't survive a reload.
    _obj setVariable ["OT_forceSaveUnowned", true, true];

    private _msg = format ["Container set as %1: %2", _role, _label];
    [AUDIT_MISSION, _msg, [_id, _role]] call BO_fnc_audit;
    _msg call OT_fnc_notifyMinor;
};
