#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_setEnabled
 *
 * Runtime master switch (Options menu, IDC 1709). Server-only; clients
 * remoteExec here. The heartbeat / watchdog / field-command PFHs are
 * always installed and self-gate on BO_HAL_enabled, so flipping the
 * flag takes effect on their next pass.
 *
 *   OFF: every active op is wound down gracefully -- field groups are
 *        RELEASED back to the world, HAL-spawned ops recycle with the
 *        standard refund. No orphaned, never-evaluated groups.
 *   ON:  VCOM globals re-applied (idempotent) and the next tick runs
 *        the world as usual.
 *
 * The choice persists across save/load via server var
 * BO_HAL_enabledOverride (fn_init applies it over the mission param).
 *
 * Params: 0: BOOL enable, 1: STRING actor UID, 2: STRING actor name
 */

SERVER_ONLY;
params [["_on", true, [true]], ["_uid", "", [""]], ["_name", "server", [""]]];

if ((missionNamespace getVariable ["BO_HAL_enabled", false]) isEqualTo _on) exitWith {};

BO_HAL_enabled = _on;
publicVariable "BO_HAL_enabled";
server setVariable ["BO_HAL_enabledOverride", _on];

if (_on) then {
    // Re-apply the VCOM contract (idempotent; VCOM is long bootstrapped
    // by the time anyone reaches the Options menu).
    if (missionNamespace getVariable ["BO_HAL_vcomActive", false] && {!isNil "Vcm_Settings"}) then {
        VCM_AISUPPRESS = false;
        VCM_ADVANCEDMOVEMENT = false;
        VCM_StealVeh = false;
        VCM_MINEENABLED = false;
        VCM_ARTYENABLE = true;
    };
} else {
    // Graceful wind-down: nothing keeps running unevaluated. Guarded
    // for the (theoretical) pre-init window -- before fn_init seeds
    // session state there is nothing to wind down.
    if (!isNil "BO_HAL_activeOps") then {
        {
            if ((_x select 12) isEqualTo "field") then {
                [_x, "hal_disabled"] call BO_HAL_fnc_releaseFieldGroup;
            } else {
                [_x, true, "hal_disabled"] call BO_HAL_fnc_recycleOp;
            };
        } forEach (+BO_HAL_activeOps);
        BO_HAL_fobActionActive = false;
        BO_HAL_provocationQueue = [];
        BO_HAL_partialPending = false;
    };
};

private _msg = format ["HAL %1 by %2", ["disabled", "enabled"] select _on, _name];
[AUDIT_ADMIN, _msg, [_on, _uid], _uid, _name] call BO_fnc_auditServer;
["toggle", [_on, _uid]] call BO_HAL_fnc_aar;
BO_LOG_INFO("hal", _msg);
_msg remoteExec ["OT_fnc_notifyMinor", 0, false];
