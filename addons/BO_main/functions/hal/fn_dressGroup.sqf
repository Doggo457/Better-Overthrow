#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_dressGroup
 *
 * The LAMBS + VCOM contract (build doc section 11, verbatim semantics).
 * HAL-driven groups own their tactics: LAMBS group AI off, VCOM off on
 * BOTH leader and every unit (version drift), TOUGHSQUAD/NORESCUE stop
 * call-ins, dangerRadio off so HAL units don't feed cluster warnings.
 * All stamps LOCAL (engine critique #3: no JIP broadcast cost).
 *
 * Params: 0: GROUP, 1: BOOL package wants LAMBS reinforce (default false)
 */

SERVER_ONLY;
params [["_grp", grpNull, [grpNull]], ["_wantsReinforce", false, [false]]];
if (isNull _grp) exitWith {};

if (missionNamespace getVariable ["BO_HAL_lambsActive", false]) then {
    _grp setVariable ["lambs_danger_enableGroupReinforce", _wantsReinforce, false];
    _grp setVariable ["lambs_danger_disableGroupAI",       true,            false];
    _grp setVariable ["lambs_danger_cqbRange",             80,              false];
};

if (missionNamespace getVariable ["BO_HAL_vcomActive", false]) then {
    (leader _grp) setVariable ["Vcm_Disable", true, false]; // version drift: leader AND units
    { _x setVariable ["Vcm_Disable", true, false] } forEach (units _grp);
    _grp setVariable ["VCM_TOUGHSQUAD", true, false];
    _grp setVariable ["VCM_NORESCUE",   true, false];
};

// Responsiveness pack (vanilla AI dithers without these): no cowering
// retreats mid-op, high courage so suppression doesn't freeze them,
// commanding up so orders propagate through the group fast, WEDGE so
// they don't accordion in column on every contact.
{
    _x setVariable ["lambs_danger_dangerRadio", false, false];
    _x allowFleeing 0;
    _x setSkill ["courage", 1];
    _x setSkill ["commanding", 0.9];
} forEach (units _grp);
_grp setFormation "WEDGE";

_grp deleteGroupWhenEmpty true;
