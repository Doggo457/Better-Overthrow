/*
    Author: ThomasAngel

    Description:
    Iterate through known targets and if possible, raid them

    Parameters:
        _spend - The current spending limit
		_chance - The current random threshold

    Usage: [_spend] call OT_fnc_NATOsendRaid;

    Returns: Scalar - How much is left to spend
*/

params ["_spend", "_chance"];

private _resources = server getVariable ["NATOresources", 2000];
// BO: defensive locals matching the sibling pattern (fn_NATOcheckTowns:22,
// fn_NATOQRF:14) so difficulty scaling doesn't rely on scope inheritance.
private _diff = server getVariable ["OT_difficulty", 1];
private _popControl = call OT_fnc_getControlledPopulation;

{
    _x params ["_ty", "_pos", "", "", ["_done", false]];
    if (!_done) then {
        private _chance = 85;
        if (_diff > 1) then { _chance = 80 };
        if (_diff < 1) then { _chance = 90 };
        if (_popControl > 1000) then { _chance = _chance - 5 };
        if (_popControl > 2000) then { _chance = _chance - 10 };

        if (_ty == "FOB") then {
            if ((random 100) > _chance) then {
                [_pos, "[this] spawn OT_fnc_NATOsiegeFOB"] call OT_fnc_NATOMissionReconInsert;
                _spend = _spend - 250;
                _resources = _resources - 250;
                break;
            };
        };
    };
// Lint-found bug: _knownTargets was never defined in this scope -- the
// whole FOB-siege roll silently errored out every cycle. The buffer is
// the global NATOknownTargets (slot layout matches the params above).
} forEach (missionNamespace getVariable ["NATOknownTargets", []]);

server setVariable ["NATOresources", _resources];

_spend;
