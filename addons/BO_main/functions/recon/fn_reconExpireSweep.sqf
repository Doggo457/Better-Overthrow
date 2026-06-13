#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconExpireSweep
 *
 * Server-only. Installs a CBA per-frame handler (10s cadence) that
 * walks BO_activeRecon and drops entries whose expireServerTime has
 * passed. Each drop is audited under AUDIT_INTEL.
 *
 * Idempotent: re-call no-ops if the handle is already installed. The
 * client side has its own per-frame fader/countdown which tears down
 * its local markers independently when serverTime crosses the boundary;
 * this sweep is purely for server-state cleanup so disconnected owners'
 * entries don't linger forever.
 */

SERVER_ONLY;

if (!isNil "BO_reconExpireSweepHandle") exitWith {
    BO_LOG_DEBUG("intel", "reconExpireSweep already installed");
};

BO_reconExpireSweepHandle = [{
    private _active = server getVariable ["BO_activeRecon", []];
    if (_active isEqualTo []) exitWith {};
    private _kept = [];
    private _now = serverTime;
    {
        _x params ["_uid", "_scope", "_key", "_expire"];
        if (_expire > _now) then {
            _kept pushBack _x;
        } else {
            private _desc = format ["Recon expired: scope=%1 key=%2 uid=%3", _scope, _key, _uid];
            [AUDIT_INTEL, _desc, _x, _uid, ""] call BO_fnc_auditServer;
        };
    } forEach _active;
    if (count _kept != count _active) then {
        server setVariable ["BO_activeRecon", _kept, true];
    };
}, 10, []] call CBA_fnc_addPerFrameHandler;

BO_LOG_INFO("intel", "Recon expire sweep installed (10s cadence)");
