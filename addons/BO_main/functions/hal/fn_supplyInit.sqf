#include "\overthrow_main\script_component.hpp"
/*
 * BO_HAL_fnc_supplyInit
 *
 * The physical NATO supply line (user-locked: the ONLY non-admin way
 * NATO gains resources -- passive recovery is removed from
 * fn_factionNATO):
 *
 *   Every real-life hour, ONE supply flight:
 *     - cargo PLANE, +1000: map edge -> NATO-held airfield, must land
 *       AND come to a stop on the runway; then takes off, flies to the
 *       map edge and deletes. Killed before the stop = nothing.
 *     - no held airfield (or no plane class in the modset): cargo
 *       HELICOPTER, +200, to a random NATO-held base, same rules.
 *
 * Multi-nation: the plane class is MINED from CfgVehicles (side west,
 * scope 2, non-UAV Plane with the biggest troop bay, faction-preferred)
 * because neither vanilla OT nor most faction mods expose a cargo-plane
 * var. Helicopter comes from OT_NATO_Vehicle_AirTransport(_Large).
 *
 * Also owns the LAST-STAND scheduler: when NATO holds ZERO bases, a
 * heavy air assault (BO_HAL_fnc_reclaimAssault) goes out every 2 real
 * hours instead of supply (nothing to deliver to).
 */

SERVER_ONLY;

if (missionNamespace getVariable ["BO_HAL_supplyInit", false]) exitWith {};
missionNamespace setVariable ["BO_HAL_supplyInit", true];

// ---- mine the cargo plane class (multi-nation) -----------------------
private _faction = missionNamespace getVariable ["OT_faction_NATO", "BLU_F"];
private _best = "";
private _bestCap = 7;   // need a real bay, not a 2-seater
private _bestFaction = false;
{
    private _cls = configName _x;
    private _cap = getNumber (_x >> "transportSoldier");
    private _isFaction = (getText (_x >> "faction")) isEqualTo _faction;
    if (_cap > _bestCap || {_isFaction && {!_bestFaction} && {_cap > 7}}) then {
        if (_isFaction || {!_bestFaction}) then {
            _best = _cls;
            _bestCap = _cap;
            _bestFaction = _isFaction;
        };
    };
} forEach (
    "(getNumber (_x >> 'scope') == 2)
     && {(getNumber (_x >> 'side')) == 1}
     && {(configName _x) isKindOf 'Plane'}
     && {(getNumber (_x >> 'isUav')) != 1}" configClasses (configFile >> "CfgVehicles")
);
BO_supplyPlaneClass = _best;

// ---- airport index table (for landAt) --------------------------------
// Index 0 = the world's main airport; SecondaryAirports follow 1..n.
private _worldCfg = configFile >> "CfgWorlds" >> worldName;
BO_supplyAirports = [[0, getArray (_worldCfg >> "ilsPosition")]];
{
    BO_supplyAirports pushBack [_forEachIndex + 1, getArray (_x >> "ilsPosition")];
} forEach ("true" configClasses (_worldCfg >> "SecondaryAirports"));

// ---- schedule state ---------------------------------------------------
private _next = server getVariable ["BO_supplyNextAt", 0];
if (_next isEqualTo 0 || {_next > serverTime + 3700}) then {
    server setVariable ["BO_supplyNextAt", serverTime + 3600];
};
private _rNext = server getVariable ["BO_reclaimNextAt", 0];
if (_rNext > serverTime + 7300) then {
    server setVariable ["BO_reclaimNextAt", serverTime + 1800];
};
BO_supplyActive = false;

[{
    if (!(missionNamespace getVariable ["BO_HAL_enabled", false])) exitWith {};
    private _now = serverTime;

    private _abandoned = server getVariable ["NATOabandoned", []];
    private _held = ((missionNamespace getVariable ["OT_objectiveData", []])
        + (missionNamespace getVariable ["OT_airportData", []])) select {
        !((_x select 1) in _abandoned)
    };

    if (_held isEqualTo []) then {
        // LAST STAND: nothing to supply -- every 2h, hit back instead.
        if (_now >= (server getVariable ["BO_reclaimNextAt", 0])) then {
            server setVariable ["BO_reclaimNextAt", _now + 7200];
            [] call BO_HAL_fnc_reclaimAssault;
        };
    } else {
        if (_now >= (server getVariable ["BO_supplyNextAt", 0]) && {!BO_supplyActive}) then {
            server setVariable ["BO_supplyNextAt", _now + 3600];
            [] spawn BO_HAL_fnc_supplyRun;
        };
    };
}, 60] call CBA_fnc_addPerFrameHandler;

private _msg = format ["Supply line online: plane=%1 airports=%2",
    [BO_supplyPlaneClass, "NONE (heli-only)"] select (BO_supplyPlaneClass isEqualTo ""),
    count BO_supplyAirports];
BO_LOG_INFO("hal", _msg);
