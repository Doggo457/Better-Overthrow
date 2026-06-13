#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_verifyIntegrity
 *
 * Inspect a load payload's BO_saveStamp entry. The stamp is set at
 * save time as [date, hashValue _dataWithoutStamp]. If the recomputed
 * hash doesn't match, the save is suspected corrupt and we log an
 * ERROR. We do NOT abort the load -- the engine will still try to
 * apply what's there, and the .prev backup slot is the recovery
 * path if the user decides to roll back.
 *
 * Params:
 *   0: ARRAY - the save payload (list of [key, val] tuples)
 *
 * Returns: BOOL - true if hash matched (or no stamp present), false on mismatch.
 */

SERVER_ONLY_RET(true);

params [["_data", [], [[]]]];

private _stampEntry = _data param [_data findIf { (_x select 0) isEqualTo "BO_saveStamp" }, []];
if (_stampEntry isEqualTo []) exitWith {
    // No stamp -- pre-BO save, or a save written before integrity was wired up.
    BO_LOG_INFO("save","verifyIntegrity: no stamp present, skipping check");
    true
};

private _stamp = _stampEntry select 1;
_stamp params [
    ["_savedDate", [], [[]]],
    ["_savedHash", 0]
];

// Recompute hash of payload minus the stamp itself.
private _payload = _data select { (_x select 0) isNotEqualTo "BO_saveStamp" };
private _currentHash = hashValue _payload;

private _matched = _currentHash isEqualTo _savedHash;
if (_matched) then {
    private _okMsg = format ["verifyIntegrity: stamp matches (saved %1)", _savedDate];
    BO_LOG_INFO("save", _okMsg);
} else {
    private _errMsg = format ["Integrity mismatch: saved hash=%1, current=%2 (stamp date %3)", _savedHash, _currentHash, _savedDate];
    BO_LOG_WARN("save", _errMsg);
    [AUDIT_SAVE, "Integrity stamp mismatch on load", [_savedHash, _currentHash, _savedDate], "", ""] call BO_fnc_auditServer;
};

_matched
