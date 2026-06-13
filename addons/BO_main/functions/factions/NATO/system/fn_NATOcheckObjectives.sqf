/*
    Author: ThomasAngel, ARMAZac

    Description:
    Loops through all objective data and checks QRF and drone reports

    Parameters:
        -

    Usage: [] call OT_fnc_NATOcheckObjectives;

    Returns: Boolean - was an objective countered (QRF sent)
*/

private _countered = false;
private _knownTargets = spawner getVariable ["NATOknownTargets", []];
private _resources = server getVariable ["NATOresources", 2000];
// Lint-found bug: _popControl was read below but never defined -- the
// population escalation multiplier silently errored every response.
private _popControl = call OT_fnc_getControlledPopulation;
private _abandoned = server getVariable ["NATOabandoned", []];

{
    _x params ["_pos", "_name", "_cost"];
    if !(_name in _abandoned) then {

        // Check if an objective is under attack
        if ([_pos] call OT_fnc_inSpawnDistance) then {
            private _numGarrison = server getVariable [format ["garrison%1", _name], 0];
            private _numMil = { side _x isEqualTo blufor } count (_pos nearEntities ["CAManBase", 500]);
            private _numRes = { side _x isEqualTo independent || captive _x } count (_pos nearEntities ["CAManBase", 100]);

            // Respond
            if (_numGarrison < 4 && _numMil < _numRes) then {
                _countered = true;
                private _multiplier = 1;
                if (_popControl > 1000) then { _multiplier = 2 };
                if (_popControl > 2000) then { _multiplier = 4 };
                _cost = _cost * _multiplier;
                server setVariable ["NATOattacking", _name, true];
                server setVariable ["NATOattackstart", time, true];
                diag_log format ["Overthrow: NATO responding to %1", _name];
                if (_resources < _cost) then { _cost = _resources };
                [_name, _cost] spawn OT_fnc_NATOResponseObjective;
                _name setMarkerAlpha 1;
                _resources = _resources - _cost;
            };
        };

        // Drone intel report
        private _drone = spawner getVariable [format ["drone%1", _name], objNull];
        if ((!isNull _drone) && { alive _drone }) then {
            private _intel = _drone getVariable ["OT_seenTargets", []];
            {
                private _added = false;
                _x params ["_ty", "_pos", "_pri", "_obj"];
                {
                    private _o = _x select 3;
                    if (_o isEqualTo _obj) then {
                        _added = true;
                    };
                } forEach (_knownTargets);

                if !(_added) then {
                    // BO HAL: 7th slot is the observedKit extension (PLAN §5);
                    // nil here keeps the schema consistent with HAL's ingest writer.
                    _knownTargets pushBack [_ty, _pos, _pri, _obj, false, time, nil];
                };
            } forEach _intel;
            _drone setVariable ["OT_seenTargets", []];
        };
    };
    if (_countered) exitWith {};
} forEach (OT_objectiveData + OT_airportData);

spawner setVariable ["NATOknownTargets", _knownTargets];
server setVariable ["NATOresources", _resources];

_countered;
