#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_reconRebaseServerTimes
 *
 * Server-only. Called from postLoadHydrate AFTER the save's server-var
 * blob is restored (so BO_activeRecon contains the persisted entries) but
 * BEFORE clients rebuild their local reveal layer via reconRebuildClient.
 *
 * Why: slot 3 of each entry is `_expireServerTime`, a session-local
 * counter. serverTime resets each mission launch, so the persisted slot 3
 * is meaningless after load -- entries either over-run their duration
 * (stale serverTime > new serverTime) or, in pathological cases, expire
 * immediately. The persisted truth lives in slot 4 (`_expireDate`), the
 * in-game world-clock snapshot, which IS preserved across save/load
 * because setDate is restored in fn_weatherSystem.
 *
 * This function walks BO_activeRecon, drops entries whose _expireDate
 * has already passed (treated as "expired while you were away"), and
 * rebases slot 3 of the survivors to `serverTime + game-seconds-remaining
 * / timeMultiplier`, so the sweep + per-frame HUD see correct values.
 */

SERVER_ONLY;

private _active = server getVariable ["BO_activeRecon", []];
if (_active isEqualTo []) exitWith {};

private _nowDateNum = dateToNumber date;
private _kept = [];
private _dropped = 0;
{
    // Defensive: drop any entry that doesn't match the expected 6-tuple
    // shape. A schema break would otherwise blow up further consumers.
    if (!(_x isEqualType []) || {count _x != 6}) then {
        _dropped = _dropped + 1;
        // BO_LOG macros split on comma — pre-build the message.
        private _wmsg = format ["Recon rebase: dropping malformed entry: %1", _x];
        BO_LOG_WARN("intel", _wmsg);
    } else {
        _x params ["_uid", "_scope", "_key", "", "_expireDate", "_cost"];
        if (!(_expireDate isEqualType []) || {count _expireDate != 6}) then {
            _dropped = _dropped + 1;
            private _wmsg = format ["Recon rebase: dropping entry with bad _expireDate: uid=%1 scope=%2 key=%3", _uid, _scope, _key];
            BO_LOG_WARN("intel", _wmsg);
        } else {
            private _expDateNum = dateToNumber _expireDate;
            // dateToNumber is a fraction WITHIN the year: an expiry that
            // crossed New Year reads as "before" now by ~a full year.
            // Recon durations are minutes, so anything more than half a
            // year in the past is a wrap, not an expiry.
            if (_expDateNum < _nowDateNum - 0.5) then {
                _expDateNum = _expDateNum + 1;
            };
            if (_expDateNum <= _nowDateNum) then {
                _dropped = _dropped + 1;
                private _imsg = format ["Recon expired during downtime: uid=%1 scope=%2 key=%3", _uid, _scope, _key];
                BO_LOG_INFO("intel", _imsg);
            } else {
                private _realSecsRemaining = ((_expDateNum - _nowDateNum) * 365.25 * 86400) / timeMultiplier;
                private _newExpire = serverTime + _realSecsRemaining;
                _kept pushBack [_uid, _scope, _key, _newExpire, _expireDate, _cost];
            };
        };
    };
} forEach _active;

server setVariable ["BO_activeRecon", _kept, true];

private _logMsg = format ["Recon rebased: kept=%1 dropped=%2", count _kept, _dropped];
BO_LOG_INFO("intel", _logMsg);
