params ["_i", "_s", "_e", "_c", "_p"];
private _groups = spawner getVariable [_i, []];

// BO: snapshot every NATO objective/comms base before cleanup so its
// garrison layout persists across the virtualization cycle. Recon is
// purely "how the player learns about the base"; persistence itself
// is universal so bases don't shuffle units to new positions every
// time you leave and return.
//
// On NATO recapture, BO_fnc_clearReconState wipes the saved layout
// so the next spawn rolls fresh -- reconquered bases come back as
// a reinforced unknown rather than the broken pre-capture layout.
//
// BO IMPROVEMENT: gate the snapshot to objectives+comms only. Only
// fn_spawnNATOObjective consumes BO_reconLayout_*; checkpoints,
// gendarmerie, businesses, civilians etc. have no restore path, so
// snapshotting them leaks unbounded server vars across long
// campaigns. Mirror the restore-path predicate at the source.
private _objectiveNames = (OT_NATOobjectives apply { _x select 1 }) + (OT_NATOcomms apply { _x select 1 });
private _basesToSnapshot = createHashMap;
{
    private _checkObj = {
        params ["_o"];
        // garrison covers infantry + HMG crew + the occasional special
        // case. vehgarrison/airgarrison cover parked vehicles whose own
        // tag (not the crew's) names the base -- without these we'd
        // miss bases whose despawn set is vehicles-only.
        {
            private _b = _o getVariable [_x, ""];
            if (_b isNotEqualTo "" && {_b in _objectiveNames}) then {
                _basesToSnapshot set [_b, true];
            };
        } forEach ["garrison", "vehgarrison", "airgarrison"];
    };
    if (_x isEqualType grpNull) then {
        { [_x] call _checkObj } forEach (units _x);
    };
    if (_x isEqualType objNull) then {
        [_x] call _checkObj;
    };
} forEach _groups;
{
    [_x, _groups] call BO_fnc_reconSnapshot;
} forEach (keys _basesToSnapshot);

spawner setVariable [_i, [], false];
{
    // Cleanup a group
    if (_x isEqualType grpNull) then {
        private _units = units _x;
        if (_units isEqualTo []) then {
            [_x] call OT_fnc_cleanupEmptyGroup;
        };
        {
            if !(_x call OT_fnc_hasOwner) then {
                [_x] call OT_fnc_cleanupUnit;
                sleep 0.1;
            };
        } forEach (_units);
        continue;
    };

    // Cleanup a vehicle / object
    if (_x isEqualType objNull) then {
        if !(_x call OT_fnc_hasOwner) then {
            [_x] call OT_fnc_cleanupVehicle;
        };
        continue;
    };

    // Cleanup a marker
    if (_x isEqualType "") then {
        deleteMarker _x;
        continue;
    };

    // We don't know what it is
    diag_log format ["Overthrow: Failed to despawn %1", _x];
} forEach (_groups);
