closeDialog 0;
private _idx = lbCurSel 1500;
private _cls = lbData [1500, _idx];

// BO: pass the player UID so the arsenal opens with their existing
// per-player loadout (if any) instead of the OT baseline.
private _soldier = [_cls, getPlayerUID player] call OT_fnc_getSoldier;

_soldier params ["", "", "_loadout", "_clothes"];

private _items = [];
//Add warehouse items to arsenal
private _warehouse = [player] call OT_fnc_nearestWarehouse;
if (_warehouse == objNull) exitWith { hint "No warehouse near by!" };
{
    if (_x select [0, 5] isEqualTo "item_") then {
        private _d = _warehouse getVariable [_x, [_x select [5], 0, [0]]];
        if (_d isEqualType []) then {
            _items pushBack _d # 0;
        };
    };
} forEach (allVariables _warehouse);

if (_items isEqualTo []) exitWith { hint "Cannot edit loadout, no items in warehouse" };

//spawn a virtual dude
private _start = (getPosATL player) findEmptyPosition [5, 100, _cls];
private _civ = (group player) createUnit [_cls, _start, [], 0, "NONE"];
_civ disableAI "MOVE";
_civ disableAI "AUTOTARGET";
_civ disableAI "TARGET";
_civ disableAI "WEAPONAIM";
_civ disableAI "FSM";

[_civ, (selectRandom OT_faces_local)] remoteExecCall ["setFace", 0, _civ];

if (_clothes != "") then {
    _civ forceAddUniform _clothes;
} else {
    _clothes = selectRandom OT_clothes_guerilla;
    _civ forceAddUniform _clothes;
};

_civ setSkill ["courage", 1];

removeAllWeapons _civ;
removeAllAssignedItems _civ;
removeGoggles _civ;
removeBackpack _civ;
removeHeadgear _civ;
removeVest _civ;

_civ setUnitLoadout [_loadout, false];
_civ setFatigue 0;

if ((_civ getVariable ["cba_projectile_firedEhId", -1]) != -1) then {
    _civ call CBA_fnc_removeUnitTrackProjectiles;
};

[_civ, true, false] call ace_arsenal_fnc_removeVirtualItems;
[_civ, _items, false] call ace_arsenal_fnc_addVirtualItems;

[
    "ace_arsenal_displayOpened",
    {
        _thisArgs params ["_unit"];
        [
            {
                switch (true) do {
                    case (primaryWeapon _this != ""): {
                        _this switchMove "amovpercmstpslowwrfldnon";
                    };
                    case (handgunWeapon _this != ""): {
                        _this switchMove "amovpercmstpslowwpstdnon";
                    };
                    default {
                        _this switchMove "amovpercmstpsnonwnondnon";
                    };
                };
            },
            _unit
        ] call CBA_fnc_execNextFrame;

        [_thisType, _thisId] call CBA_fnc_removeEventHandler;
    },
    [_civ]
] call CBA_fnc_addEventHandlerArgs;

[
    "ace_arsenal_displayClosed",
    {
        _thisArgs params ["_unit", "_cls"];
        private _loadout = getUnitLoadout _unit;

        // BO: stash per-player so two players editing the same unit
        // class don't overwrite each other (and no publicVariable
        // broadcast). Future recruits by this player use this loadout.
        [_cls, _loadout] call BO_fnc_savePlayerLoadout;

        // MP race: ace_arsenal_fnc_addDefaultLoadout mutates a local
        // cache; broadcasting it to all clients clobbered each player's
        // own per-unit loadout list. Save is already persisted per
        // player via BO_fnc_savePlayerLoadout above.
        [_cls call OT_fnc_vehicleGetName, _loadout] call ace_arsenal_fnc_addDefaultLoadout;

        playSound "3DEN_notificationDefault";
        "Saved loadout" call OT_fnc_notifyMinor;

        [_unit] call OT_fnc_cleanupUnit;

        [_thisType, _thisId] call CBA_fnc_removeEventHandler;
    },
    [_civ, _cls]
] call CBA_fnc_addEventHandlerArgs;

[_civ, _civ] call ace_arsenal_fnc_openBox;
