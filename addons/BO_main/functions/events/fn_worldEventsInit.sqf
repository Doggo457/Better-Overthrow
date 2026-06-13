#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_worldEventsInit
 *
 * Server-only bootstrap for the World Demand Events system.
 *
 *   1. Builds BO_eventItemBuckets: maps category tokens ("@Pharmacy",
 *      "@food", ...) to arrays of item classnames. Falls back to []
 *      for any bucket whose source list is missing so the price hook
 *      never crashes on a missing curated list.
 *
 *   2. Builds BO_eventCatalog: 14 event-type specs of the shape
 *      [_type, _displayName, _boostedItems, [_loMul,_hiMul],
 *       _townFilter:CODE, _weight, _shopHint].
 *
 *   3. Seeds BO_activeWorldEvents (server var, broadcast) to [] and
 *      BO_eventLastMidnight (server var, broadcast) to -1 if either
 *      is nil. Both ride the slot-1 server-var save loop.
 *
 *   4. Installs BO_fnc_worldEventsLoop, the per-frame ticker.
 *
 * Idempotent: safe to call multiple times. Re-entry short-circuits on
 * BO_eventInitDone.
 */

SERVER_ONLY;

if (!isNil "BO_eventInitDone") exitWith {
    BO_LOG_DEBUG("events", "worldEventsInit already done");
};

// ------------------------------------------------------------------
// Item buckets. "@<token>" -> array of classnames.
//
// _findBucket extracts the classname list from OT_itemCategoryDefinitions
// (shape: [[catName, [classes...]], ...]) for a given category name.
// Returns [] if the category isn't present so subsequent lookups
// degrade gracefully.
// ------------------------------------------------------------------
private _findBucket = {
    params ["_catName"];
    private _out = [];
    {
        if ((_x select 0) isEqualTo _catName) exitWith {
            _out = _x select 1;
        };
    } forEach OT_itemCategoryDefinitions;
    _out
};

BO_eventItemBuckets = createHashMap;
BO_eventItemBuckets set ["@Pharmacy",    ["Pharmacy"]    call _findBucket];
BO_eventItemBuckets set ["@Electronics", ["Electronics"] call _findBucket];
BO_eventItemBuckets set ["@Hardware",    ["Hardware"]    call _findBucket];

private _clothing = [];
if (!isNil "OT_clothes_locals") then { _clothing = _clothing + OT_clothes_locals };
if (!isNil "OT_clothes_shops")  then { _clothing = _clothing + OT_clothes_shops };
BO_eventItemBuckets set ["@Clothing", _clothing];

BO_eventItemBuckets set ["@food", [
    "ACE_MRE_BeefStew", "ACE_MRE_ChickenTikkaMasala",
    "ACE_MRE_LambCurry", "ACE_MRE_SteakVegetables",
    "ACE_MRE_MeatballsPasta", "ACE_MRE_ChickenHerbDumplings",
    "ACE_MRE_CreamChickenSoup", "ACE_MRE_CreamTomatoSoup",
    "Banana"
]];
BO_eventItemBuckets set ["@water", ["ACE_WaterBottle", "ACE_Canteen"]];
BO_eventItemBuckets set ["@alcohol", ["OT_Wine", "ACE_Can_Spirit"]];
BO_eventItemBuckets set ["@fuel", ["FUEL"]];
BO_eventItemBuckets set ["@drugs", (if (isNil "OT_allDrugs") then { [] } else { OT_allDrugs })];
BO_eventItemBuckets set ["@construction",
    ["OT_Wood", "OT_Lumber", "OT_Steel", "OT_Plastic"]];
BO_eventItemBuckets set ["@weapons",
    (if (isNil "OT_allWeapons") then { [] } else { OT_allWeapons })];
BO_eventItemBuckets set ["@ammo",
    (if (isNil "OT_allMagazines") then { [] } else { OT_allMagazines })];
BO_eventItemBuckets set ["@flags", ["FlagCarrierAAF"]];

// ------------------------------------------------------------------
// Event catalog. Each entry:
//   [_type, _displayName, _boostedItems, [_loMul,_hiMul],
//    _townFilter:CODE, _weight, _shopHint]
//
// _townFilter is invoked as [_town] call _filter and returns BOOL.
// Heavier _weight = higher chance to be picked for an eligible town.
// ------------------------------------------------------------------
BO_eventCatalog = [
    ["disease", "Disease outbreak",
        ["@Pharmacy", "@food", "@water"],
        [2.5, 3.0],
        { true },
        10, "medical/MRE/water"],

    ["wedding", "Wedding",
        ["@alcohol", "@food", "@Clothing"],
        [1.5, 2.0],
        {
            params ["_town"];
            (server getVariable [format ["stability%1", _town], 100]) > 60
            && {(server getVariable [format ["population%1", _town], 0]) > 500}
        },
        8, "alcohol/food/clothing"],

    ["funeral", "Funeral",
        ["@alcohol", "@food"],
        [1.5, 1.8],
        { true },
        5, "alcohol/food"],

    ["religious", "Religious holiday",
        ["@food"],
        [1.5, 1.7],
        {
            params ["_town"];
            !isNil { server getVariable (format ["churchin%1", _town]) }
        },
        8, "food"],

    ["refugee", "Refugee influx",
        ["@food", "@water", "@Clothing", "@Pharmacy"],
        [2.0, 2.0],
        { true },
        6, "food/water/clothing/medical"],

    ["coldsnap", "Cold snap",
        ["@Clothing", "@fuel"],
        [1.5, 2.0],
        {
            params ["_town"];
            private _pos = server getVariable _town;
            if (isNil "_pos") exitWith { false };
            ((_pos select 2) > 100) || {_town in (if (isNil "OT_capitals") then { [] } else { OT_capitals })}
        },
        6, "clothing/fuel"],

    ["outage", "Power outage",
        ["@Electronics", "@fuel"],
        [2.0, 2.0],
        { true },
        7, "electronics/fuel"],

    ["crime", "Crime spike",
        ["@weapons", "@ammo"],
        [2.0, 2.5],
        {
            params ["_town"];
            (server getVariable [format ["stability%1", _town], 100]) < 40
        },
        8, "weapons/ammo"],

    ["antinato", "Anti-NATO surge",
        ["@flags", "@weapons"],
        [2.0, 2.0],
        {
            params ["_town"];
            _town in (server getVariable ["NATOabandoned", []])
        },
        6, "flags/weapons"],

    ["construction", "Construction boom",
        ["@construction"],
        [1.5, 2.0],
        {
            params ["_town"];
            (server getVariable [format ["stability%1", _town], 100]) > 70
        },
        5, "wood/steel/plastic"],

    ["hunting", "Hunting season",
        ["@weapons", "@ammo"],
        [1.5, 1.5],
        {
            params ["_town"];
            (server getVariable [format ["population%1", _town], 0]) < 400
        },
        4, "rifles/ammo"],

    ["hardware", "Hardware shortage",
        ["@Hardware"],
        [2.0, 2.0],
        { true },
        7, "tools/hardware"],

    ["blackmarket", "Black market window",
        ["@drugs", "@weapons"],
        [2.0, 3.0],
        {
            params ["_town"];
            (server getVariable [format ["stability%1", _town], 100]) < 30
        },
        5, "drugs/weapons"],

    ["cropfail", "Crop failure",
        ["@food", "@water"],
        [2.0, 2.0],
        { true },
        5, "food/water"]
];

// ------------------------------------------------------------------
// Seed persisted state. Both are server vars; the BO_ prefix puts
// them on the slot-1 save loop. Don't overwrite values restored by
// loadGame.
// ------------------------------------------------------------------
if (isNil { server getVariable "BO_activeWorldEvents" }) then {
    server setVariable ["BO_activeWorldEvents", [], true];
};
if (isNil { server getVariable "BO_eventLastMidnight" }) then {
    server setVariable ["BO_eventLastMidnight", -1, true];
};

BO_eventInitDone = true;

// Broadcast the buckets + catalog so client-side OT_fnc_getPrice /
// OT_fnc_getSellPrice (which run BO_fnc_worldEventMultiplier locally)
// can resolve @bucket tokens. Without this, dedicated-server clients
// see empty hashmap fallbacks and the multiplier is always 1.0 even
// though active events display in the Y-menu.
publicVariable "BO_eventItemBuckets";
publicVariable "BO_eventCatalog";
publicVariable "BO_eventInitDone";

// JIP replay: publicVariable does not auto-deliver to clients that
// connect later. Re-publish to each new owner so JIPers can resolve
// event prices the same as players who were there at init time.
if (isNil "BO_eventInitPlayerConnectEH") then {
    BO_eventInitPlayerConnectEH = addMissionEventHandler ["PlayerConnected", {
        params ["", "", "", "_jip", "_owner"];
        if (!_jip) exitWith {};
        if (_owner < 2) exitWith {};
        // Lint-found bug: publicVariableClient takes the CLIENT ID on
        // the LEFT. Reversed args meant JIP clients never received the
        // event buckets/catalog -- demand-event prices looked vanilla
        // to anyone who joined mid-session.
        _owner publicVariableClient "BO_eventItemBuckets";
        _owner publicVariableClient "BO_eventCatalog";
        _owner publicVariableClient "BO_eventInitDone";
    }];
};

[] call BO_fnc_worldEventsLoop;

private _msg = format ["World demand events initialized: %1 catalog specs, %2 active",
    count BO_eventCatalog,
    count (server getVariable ["BO_activeWorldEvents", []])];
BO_LOG_INFO("events", _msg);
