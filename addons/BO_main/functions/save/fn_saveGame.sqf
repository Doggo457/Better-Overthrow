#include "\overthrow_main\script_component.hpp"
params [["_user", objNull], ["_quiet", false], ["_autoSave", false]];

// MP race: scheduler can preempt between read and write of OT_saving,
// allowing two concurrent saves through the guard. Wrapping the
// compare-and-set in isNil { ... } runs the block in unscheduled
// context (atomic against preemption). The block returns nil only
// when it acquired the lock -- we use that as the "took it" signal so
// _lockAcquired is a per-thread local untouched by sibling threads.
private _lockToken = diag_tickTime;
private _lockAcquired = isNil {
    if (missionNamespace getVariable ["OT_saving", false]) exitWith {
        false // observed lock held -- return non-nil so isNil = false
    };
    missionNamespace setVariable ["OT_saving", true, true];
    missionNamespace setVariable ["BO_savingToken", _lockToken, false];
    // fall through: block returns nil -> isNil = true (lock acquired)
};

if !(_lockAcquired) exitWith {
    if !(_quiet) then {
        "Please wait, save still in progress" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
    };
};

// Watchdog: if the save thread dies or is otherwise terminated before
// it can clear the lock at the end, OT_saving stays true forever and
// every subsequent save attempt is rejected. Clear it after 5 minutes
// IFF the token still matches this attempt (so we don't stomp a later
// legitimate save).
[
    {
        params ["_token"];
        if ((missionNamespace getVariable ["BO_savingToken", -1]) isEqualTo _token
            && { missionNamespace getVariable ["OT_saving", false] }) then {
            missionNamespace setVariable ["OT_saving", false, true];
            missionNamespace setVariable ["BO_savingToken", nil, false];
            BO_LOG_WARN("save", "Save watchdog cleared stranded OT_saving lock");
            [AUDIT_SAVE, "Save watchdog cleared stranded OT_saving lock", [_token], "", ""] call BO_fnc_auditServer;
        };
    },
    [_lockToken],
    300
] call CBA_fnc_waitAndExecute;

if ((count allDeadMen) > 300) exitWith {
    if !(_quiet) then {
        "Too many dead bodies, please clean first" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
    };
    missionNamespace setVariable ["OT_saving", false, true];
    missionNamespace setVariable ["BO_savingToken", nil, false];
};

if (isNil "OT_NATOInitDone") exitWith {
    if !(_quiet) then {
        "NATO Init process is not done, wait a bit and try again" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
    };
    missionNamespace setVariable ["OT_saving", false, true];
    missionNamespace setVariable ["BO_savingToken", nil, false];
};

{
    _x setVariable ["OT_newplayer", false, true];
} forEach ([] call CBA_fnc_players);

OT_autoSave_last_time = time + (OT_autoSave_time * 60);

if !(_quiet) then {
    "Persistent Saving..." remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

if !(_quiet) then {
    "Step 1/11 - Saving game state" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

// BO HAL hook: flush HAL's working memory (heat cache et al.) into the
// server namespace BEFORE the walk below collects it. Without this, a
// save taken between HAL ticks could miss up to one tick interval of
// strategic memory (fn_persist otherwise only runs at tick time).
if (!isNil "BO_HAL_fnc_persist" && {missionNamespace getVariable ["BO_HAL_enabled", false]}) then {
    call BO_HAL_fnc_persist;
};

// Save game array
private _data = [];

// get all server data
private _server = (allVariables server select {

    private _val = server getVariable _x;
    if (isNil "_val") then {
        false;
    } else {

        _x = toLower _x;
        !(_x in ["startuptype", "recruits", "squads", "marta_reveal"])
            && { !("diwako_dui" in _x) } // Diwako DUI
            && { !("bettinv_" in _x) } // Better Inventory..?
            && { !("emr_main" in _x) } // Enhanced Movement rework
            && { (_x select [0, 11]) != "resgarrison" }
            && { !((_x select [0, 9]) in ["seencache", "essp_core"]) } // Enhanced soundscape plus
            && { !((_x select [0, 4]) in ["ace_", "cba_", "bis_", "l_es"]) } // Enhanced soundscape
            && { !((_x select [0, 7]) in ["@attack", "@counte", "@assaul"]) };
    };
}) apply {
    private _val = server getVariable _x;

    // copy array, we might modify them
    if (_val isEqualType []) then { _val = +_val };

    // dont abondon current attacks
    if (_x isEqualTo "natoabandoned") then {
        _val deleteAt (_val find (server getVariable ["NATOattacking", ""]));
    };

    [_x, _val];
};

if !(_quiet) then {
    "Step 2/11 - Saving buildings" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _prefixFilter = { !((toLower _x select [0, 4]) in ["ace_", "cba_", "bis_", "____"]) };
private _nilFilter = {
    params [
        ["_namespace", objNull],
        ["_value", ""]
    ];
    !(isNil { _namespace getVariable _value });
};

private _poses = ((allVariables buildingpositions select _prefixFilter) select { [buildingpositions, _x] call _nilFilter }) apply {
    [_x, buildingpositions getVariable _x];
};
_data pushBack ["buildingpositions", _poses];

if !(_quiet) then {
    "Step 3/11 - Saving civilians" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _civs = ((allVariables OT_civilians select _prefixFilter) select { [OT_civilians, _x] call _nilFilter }) apply {
    [_x, OT_civilians getVariable _x];
};
_data pushBack ["civilians", _civs];

if !(_quiet) then {
    "Step 4/11 - Saving player data" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

//get all online player data
{
    [_x] call OT_fnc_savePlayerData;
} forEach ([] call CBA_fnc_players);

private _players = ((allVariables players_NS) select { [players_NS, _x] call _nilFilter }) apply {
    [_x, players_NS getVariable _x];
};
_data pushBack ["players", _players];

private _cfgVeh = configFile >> "CfgVehicles";
private _tocheck = ((allMissionObjects "Static") + vehicles) select {
    (alive _x)
        && { (typeOf _x != OT_flag_IND) }
        && { !(typeOf _x isKindOf ["CAManBase", _cfgVeh]) }
        && { (_x call OT_fnc_hasOwner) || (_x getVariable ["OT_forceSaveUnowned", false]) }
        && { (_x getVariable ["OT_garrison", false]) isEqualTo false }
        && { !(_x getVariable ["BO_storingInProgress", false]) }
};

private _tosave = count _tocheck;
if !(_quiet) then {
    format ["Step 5/11 - Saving vehicles (%1 to save)", _tosave] remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _count = 0;
private _saved = 0;
private _vehicles = (_tocheck) apply {
    _saved = _saved + 1;
    _count = _count + 1;
    if (!_quiet && { _count % 200 == 0 }) then {
        format ["Step 5/11 - Saving vehicles (%1 to save)", _tosave - _saved] remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
    };

    // BO: full-fidelity strip-and-unpack for containers (cargo nets,
    // ammoboxes, supply crates). OT_fnc_unitStock loses weapon
    // attachments on bag-internal weapons; BO_fnc_flattenContainerCargo
    // gets the lot. Non-container objects fall through to unitStock
    // unchanged so vehicle/safe/etc. semantics aren't disturbed.
    private _type = typeOf _x;
    private _s = if ((_x isKindOf "ReammoBox_F") || (_x isKindOf "Slingload_01_Base_F") || (_type isEqualTo OT_item_Storage)) then {
        [_x] call BO_fnc_flattenContainerCargo
    } else {
        _x call OT_fnc_unitStock
    };

    if (_type == OT_item_safe) then {
        _s pushBack ["money", _x getVariable ["money", 0]];
        _s pushBack ["password", _x getVariable ["password", ""]];
    };
    private _simCheck = dynamicSimulationEnabled _x || { simulationEnabled _x };
    private _params = [
        /* 0 */
        _type,
        /* 1 */
        [getPosWorld _x, _simCheck, 1], // 1 stands for the new posWorld format
        /* 2 */
        [vectorDir _x, vectorUp _x],
        /* 3 */
        _s,
        /* 4 */
        ["", _x call OT_fnc_getOwner] select (_x call OT_fnc_hasOwner), // Save an empty string if the object doesn't have an owner (yet)
        /* 5 */
        _x getVariable ["name", ""],
        /* 6 */
        _x getVariable ["OT_init", ""]
    ];

    if ((_type isKindOf ["AllVehicles", _cfgVeh] && !(_x getVariable ["OT_garrison", false])) || { _type isEqualTo OT_item_Storage }) then {
        private _veh = _x;
        private _ammo = (_x weaponsTurret [0]) apply {
            [_x, _veh ammo _x];
        };
        private _attachedClass = _veh getVariable ["OT_attachedClass", ""];
        private _attached = _veh getVariable ["OT_attachedWeapon", objNull];
        private _att = [];

        //get attached ammo (if applicable)
        if ((_attachedClass isNotEqualTo "") && { alive _attached }) then {
            _att = [_attachedClass, (_attached weaponsTurret [0]) apply { [_x, _attached ammo _x] }];
        };
        /* 7 */
        _params set [7, [fuel _x, getAllHitPointsDamage _x, _x call ace_refuel_fnc_getFuel, _x getVariable ["OT_locked", false], _ammo, _att]];
    };

    // If the house is player-built, save some extra variables
    if (_x getVariable ["OT_house_isPlayerBuilt", false]) then {
        /* 8 */
        _params set [8, [_x getVariable ["OT_house_isLeased", false]]];
    };

    // BO: logistics tag persistence at slot 9. Containers in the
    // logistics network carry [containerId, role, label, ownerUID]
    // -- everything the route data depends on for the resolver to
    // re-find the box after a reload. Empty array if untagged.
    // BO_factoryCrate and BO_businessCrate flags also persist here so
    // initFactory / businessEnsureCrate's rebind checks still
    // recognise the saved crate after a reload.
    private _logistics = [];
    private _hasLogistics = (_x getVariable ["BO_logisticsContainerId", ""]) isNotEqualTo "";
    private _isFactoryCrate  = _x getVariable ["BO_factoryCrate", false];
    private _isBusinessCrate = _x getVariable ["BO_businessCrate", false];
    if (_hasLogistics || _isFactoryCrate || _isBusinessCrate) then {
        _logistics = [
            _x getVariable ["BO_logisticsContainerId", ""],
            _x getVariable ["BO_logisticsRole", ""],
            _x getVariable ["BO_logisticsLabel", ""],
            _x getVariable ["BO_logisticsOwner", ""],
            _isFactoryCrate,
            _isBusinessCrate
        ];
    };
    if (_logistics isNotEqualTo []) then {
        // Make sure slots 7 and 8 exist so slot 9 doesn't get
        // shifted into an OT-defined position on objects that don't
        // populate fuel/house data.
        if (count _params < 8) then { _params set [7, []] };
        if (count _params < 9) then { _params set [8, []] };
        /* 9 */
        _params set [9, _logistics];
    };

    // BO: multi-factory per-object state at slot 10. Each placed
    // factory carries its own queue / producing / producetime /
    // enabled flag / display name. Empty array for non-factory
    // objects so the slot stays type-stable.
    if (_type isEqualTo OT_factory) then {
        private _factoryState = [
            _x getVariable ["BO_queue", []],
            _x getVariable ["BO_producing", ""],
            _x getVariable ["BO_producetime", 0],
            _x getVariable ["BO_factoryEnabled", true],
            _x getVariable ["BO_factoryName", ""]
        ];
        // BO_outputContainer is NOT saved -- object references don't
        // survive a save/load round trip (new net IDs on respawn).
        // The crate it points at is independently saved as a regular
        // OT_item_CargoContainer with BO_factoryCrate=true (slot 9).
        // At load time, BO_fnc_factoryEnsureOutputContainer re-binds
        // by scanning nearby BO_factoryCrate-tagged crates.
        if (count _params < 8)  then { _params set [7, []] };
        if (count _params < 9)  then { _params set [8, []] };
        if (count _params < 10) then { _params set [9, []] };
        /* 10 */
        _params set [10, _factoryState];

        // Mark factories for save even if unowned -- placed factories
        // get setOwner via initFactory, but pre-baked starter buildings
        // that the player bought may not have a clean OT owner record.
        _x setVariable ["OT_forceSaveUnowned", true, true];
    };

    // BO: production-business per-object state at slot 11. Each
    // placed business (Lumberyard, Mine, Vineyard, Winery, Olive
    // Plantation, Chemical Plant) carries its type + enabled flag +
    // last hour ticked. The BO_businessIOCrate object ref is NOT
    // saved -- the I/O crate persists independently as a normal
    // OT_item_CargoContainer tagged BO_businessCrate=true (slot 9).
    // BO_fnc_businessEnsureCrate rebinds by scanning nearby tagged
    // crates after load.
    if ((_x getVariable ["BO_businessType", ""]) isNotEqualTo "") then {
        private _businessState = [
            _x getVariable ["BO_businessType", ""],
            _x getVariable ["BO_businessEnabled", true],
            _x getVariable ["BO_businessLastHour", -1]
        ];
        if (count _params < 8)  then { _params set [7, []] };
        if (count _params < 9)  then { _params set [8, []] };
        if (count _params < 10) then { _params set [9, []] };
        if (count _params < 11) then { _params set [10, []] };
        /* 11 */
        _params set [11, _businessState];
        _x setVariable ["OT_forceSaveUnowned", true, true];
    };

    // BO: vehicle insurance state at slot 12. Decoupled from factory/
    // business slots so it lives on ANY vehicle regardless of role.
    // Only written for insured vehicles -- the slot stays absent
    // otherwise.
    if (_x getVariable ["BO_insured", false]) then {
        private _insurancePayload = [
            true,
            _x getVariable ["BO_insurancePremium", 0],
            _x getVariable ["BO_insurancePayoutTarget", ""],
            _x getVariable ["BO_insuranceValueAtPolicy", 0]
        ];
        if (count _params < 8)  then { _params set [7, []] };
        if (count _params < 9)  then { _params set [8, []] };
        if (count _params < 10) then { _params set [9, []] };
        if (count _params < 11) then { _params set [10, []] };
        if (count _params < 12) then { _params set [11, []] };
        /* 12 */
        _params set [12, _insurancePayload];
        _x setVariable ["OT_forceSaveUnowned", true, true];
    };

    // BO artillery slot 13: per-mortar cooldown stamp + owner UID +
    // cached cooldown duration. Mortar Position vehicles ride the
    // generic vehicles save path; this slot piggybacks the per-object
    // state so loadGame can restore BO_lastFireMission etc. before
    // BO_fnc_initMortar's slot-6 OT_init replay runs.
    if (_type isEqualTo "B_Mortar_01_F") then {
        private _mortarState = [
            _x getVariable ["BO_lastFireMission", 0],
            _x getVariable ["BO_mortarOwnerUID", ""],
            _x getVariable ["BO_mortarCooldown", 300]
        ];
        if (count _params < 8)  then { _params set [7, []] };
        if (count _params < 9)  then { _params set [8, []] };
        if (count _params < 10) then { _params set [9, []] };
        if (count _params < 11) then { _params set [10, []] };
        if (count _params < 12) then { _params set [11, []] };
        if (count _params < 13) then { _params set [12, []] };
        /* 13 */
        _params set [13, _mortarState];
        _x setVariable ["OT_forceSaveUnowned", true, true];
    };

    // BO CAS slot 14: per-helipad CAS-enable flag + last-dispatch
    // stamp. Helipads are ordinary buildables with no OT_init code,
    // so they ride the normal vehicles save path with no rehydrate
    // replay -- slot 14 alone carries the cooldown stamp.
    if (_x getVariable ["BO_helipadCASEnabled", false]) then {
        private _casState = [
            _x getVariable ["BO_helipadCASEnabled", false],
            _x getVariable ["BO_lastCASMission", 0]
        ];
        if (count _params < 8)  then { _params set [7, []] };
        if (count _params < 9)  then { _params set [8, []] };
        if (count _params < 10) then { _params set [9, []] };
        if (count _params < 11) then { _params set [10, []] };
        if (count _params < 12) then { _params set [11, []] };
        if (count _params < 13) then { _params set [12, []] };
        if (count _params < 14) then { _params set [13, []] };
        /* 14 */
        _params set [14, _casState];
        _x setVariable ["OT_forceSaveUnowned", true, true];
    };

    _params;
};
_data pushBack ["vehicles", _vehicles];

if !(_quiet) then {
    "Step 6/11 - Saving warehouse" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _warehouse = [2]; //First element is save version
//_warehouse append ((allVariables warehouse) select {((toLower _x select [0,5]) isEqualTo "item_")} apply {
//	warehouse getVariable _x
//});

private _warehouselist = warehouse getVariable ["owned", []];
{
    private _currentWarehouse = _x;
    _warehouse pushBack [
        getPosATL _currentWarehouse,
        [] + (allVariables _currentWarehouse) select { (toLower _x select [0, 5]) isEqualTo "item_" } apply { _currentWarehouse getVariable [_x, ["", 0]] },
        _currentWarehouse getVariable ["is_shared", false]
    ];
} forEach _warehouselist;

private _warehouselistsave = _warehouselist apply { getPosATL _x };

_data pushBack ["warehouse", _warehouse];
_data pushBack ["warehouselist", _warehouselistsave];
_data pushBack ["warehouseshared", ((allVariables warehouse_shared) select { (toLower _x select [0, 5]) isEqualTo "item_" } apply { warehouse_shared getVariable [_x, ["", 0]] })];

if !(_quiet) then {
    "Step 7/11 - Saving recruits" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _recruits = ((server getVariable ["recruits", []]) select {
    !((_x select 2) isEqualType objNull)
        || { alive (_x select 2) }
}) apply {
    private _d = _x select [0, 7];
    if (count _x == 6) then { _d pushBack 0 };

    _x params ["", "", "_unitOrPos"];
    if (_unitOrPos isEqualType objNull) then {
        _d set [4, getUnitLoadout _unitOrPos];
        _d set [2, getPosATL _unitOrPos];
        _d set [6, _unitOrPos getVariable ["OT_xp", 0]];
    };

    _d;
};
_data pushBack ["recruits", _recruits];

if !(_quiet) then {
    "Step 8/11 - Saving squads" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _squads = ((server getVariable ["squads", []]) select {
    _x params ["_owner", "_cls", "_group"];
    _group isEqualType grpNull
        && { units _group isNotEqualTo [] }
        && { (units _group) findIf { alive _x } != -1 };
}) apply {
    _x params ["_owner", "_cls", "_group"];
    private _units = [];
    {
        if (alive _x) then {
            _units pushBack [typeOf _x, getPos _x, getUnitLoadout _x];
        };
    } forEach (units _group);
    [_owner, _cls, "Not a group, pls recreate", _units, groupId _group];
};
_data pushBack ["squads", _squads];

if !(_quiet) then {
    "Step 9/11 - Saving bases" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

private _getGroupSoldiers = {
    (units _this select {
        private _veh = vehicle _x;
        alive _x && { _veh isEqualTo _x || { (someAmmo _veh && toLower typeOf _veh in ["i_hmg_01_high_f", "i_gmg_01_high_f"]) } };
    }) apply {
        if (isNull objectParent _x) then {
            [typeOf _x, getUnitLoadout _x];
        } else {
            if (typeOf objectParent _x == "I_HMG_01_high_F") then { ["HMG", []] } else { ["GMG", []] };
        };
    };
};

{
    _x params ["_pos"];
    private _code = format ["fob%1", _pos];
    private _group = spawner getVariable [format ["resgarrison%1", _code], grpNull];
    if !(isNull _group) then {
        private _soldiers = _group call _getGroupSoldiers;
        if (_soldiers isNotEqualTo []) then {
            _server pushBack [format ["resgarrison%1", _code], _soldiers];
        };
    };
} forEach (server getVariable ["bases", []]);

if !(_quiet) then {
    "Step 10/11 - Saving garrisons" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

{
    _x params ["", "_code"];
    private _group = spawner getVariable [format ["resgarrison%1", _code], grpNull];
    if !(isNull _group) then {
        private _soldiers = _group call _getGroupSoldiers;
        if (_soldiers isNotEqualTo []) then {
            _server pushBack [format ["resgarrison%1", _code], _soldiers];
        };
    };
} forEach (OT_objectiveData + OT_airportData);

_data pushBack ["server", _server];
_data pushBack ["timedate", date];
_data pushBack ["autosave", [OT_autoSave_time, OT_autoSave_last_time]];
_data pushBack ["recruitables", OT_Recruitables];
_data pushBack ["policeLoadout", OT_Loadout_Police];

// BO: starter-factory state snapshot. The starter factory is a
// pre-baked Bohemia map building; it's NOT in allMissionObjects
// "Static" + vehicles (it's part of the terrain), so the slot-10
// per-object persistence doesn't catch it. We identify it by
// proximity to OT_factoryPos and snapshot its BO_queue / producing
// / producetime / enabled / name onto the save payload. Player-
// placed factories take the slot-10 path and skip this entry.
private _starterFactoryState = [];
if (!isNil "OT_factoryPos" && {!isNil "OT_factory"}) then {
    private _starter = OT_factoryPos nearestObject OT_factory;
    if (!isNull _starter && {(_starter distance OT_factoryPos) < 50}) then {
        _starterFactoryState = [
            _starter getVariable ["BO_queue", []],
            _starter getVariable ["BO_producing", ""],
            _starter getVariable ["BO_producetime", 0],
            _starter getVariable ["BO_factoryEnabled", true],
            _starter getVariable ["BO_factoryName", ""]
        ];
    };
};
_data pushBack ["BO_starterFactoryState", _starterFactoryState];

if !(_quiet) then {
    "Step 11/11 - Exporting" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

// --- BO: rotate the prior good save to the .prev backup slot, then
// stamp this payload so a future load can spot corruption.
[] call BO_fnc_backupSave;
private _stamp = [date, hashValue _data];
_data pushBack ["BO_saveStamp", _stamp];

missionProfileNamespace setVariable [OT_saveName, _data];
saveMissionProfileNamespace;

if (isDedicated) then {
    if !(_quiet) then {
        "Saving to dedicated server.. not long now" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
    };
};

if !(_quiet) then {
    "Persistent Save Completed" remoteExecCall ["OT_fnc_notifyAndLog", 0, false];
};

if (!_autoSave && (_user isNotEqualTo objNull)) then {
    [_data] remoteExec ["OT_fnc_uploadData", _user, false];
};

// Only clear the lock if it still belongs to THIS save attempt.
// If the 5-minute watchdog already fired (slow save), OT_saving is
// already cleared and a SUBSEQUENT save attempt may now hold the
// lock under its own BO_savingToken. Stomping it would let a third
// save start mid-write and corrupt the profile. Token-guard matches
// the pattern the watchdog itself uses at lines 33-36.
if ((missionNamespace getVariable ["BO_savingToken", -1]) isEqualTo _lockToken) then {
    missionNamespace setVariable ["OT_saving", false, true];
    missionNamespace setVariable ["BO_savingToken", nil, false];
};
