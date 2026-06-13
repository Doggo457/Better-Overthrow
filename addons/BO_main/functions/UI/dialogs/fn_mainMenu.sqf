closeDialog 0;
createDialog "OT_dialog_main";

openMap false;

private _ft = server getVariable ["OT_fastTravelType", 1];
if (!OT_adminMode && _ft > 1) then {
    ctrlEnable [1600, false];
};

disableSerialization;
private _buildingtextctrl = (findDisplay 8001) displayCtrl 1102;

private _town = player call OT_fnc_nearestTown;

private _weather = "Clear";
if (overcast > 0.4) then {
    _weather = "Cloudy";
};
if (rain > 0.1) then {
    _weather = "Rain";
};
if (rain > 0.9) then {
    _weather = "Storm";
};

private _ctrl = (findDisplay 8001) displayCtrl 1100;
private _standing = [_town] call OT_fnc_support;

private _rep = server getVariable ["rep", 0];
private _extra = "";

if ((getPlayerUID player) in (server getVariable ["generals", []])) then {
    _extra = format [
        "<t align='left' size='0.65'>Resistance Funds: $%1 (Tax Rate %2%3)</t>",
        [server getVariable ["money", 0], 1, 0, true] call CBA_fnc_formatNumber,
        server getVariable ["taxrate", 0],
        "%"
    ];
};

_ctrl ctrlSetStructuredText parseText format [
    "
		<t align='left' size='0.65'>Resistance Support: %1 (%2%3) %4 (%5%6)</t><br/>
		<t align='left' size='0.65'>Influence: %7</t><br/>
		<t align='left' size='0.65'>Weather: %8 (Forecast: %9)</t><br/>
		<t align='left' size='0.65'>Fuel Price: $%10/L</t><br/>
		%11
	",
    _town,
    ["", "+"] select (_standing > -1),
    _standing,
    OT_nation,
    ["", "+"] select (_rep > -1),
    _rep,
    player getVariable ["influence", 0],
    _weather,
    server getVariable "forecast",
    [OT_nation, "FUEL", 100] call OT_fnc_getPrice,
    _extra
];

_ctrl = (findDisplay 8001) displayCtrl 1106;
_ctrl ctrlSetStructuredText parseText format [
    "<t align='right' size='0.9'>$%1</t>",
    [player getVariable ["money", 0], 1, 0, true] call CBA_fnc_formatNumber
];

//Nearest building info
private _b = player call OT_fnc_nearestRealEstate;
private _buildingTxt = "";

if (_b isEqualType []) then {
    _b params ["_building", "_price", "_sell", "_lease"];

    private _cls = typeOf _building;
    ([_cls, true] call OT_fnc_getClassDisplayInfo) params ["_pic", "_name"];

    ctrlSetText [1201, _pic];

    if (_building call OT_fnc_hasOwner) then {
        private _owner = _building call OT_fnc_getOwner;
        private _ownername = players_NS getVariable format ["name%1", _owner];
        if (isNil "_ownername") then { _ownername = "Someone" };

        if (_cls isEqualTo OT_warehouse) exitWith {
            ctrlEnable [1609, true];
            ctrlSetText [1609, "Procurement"];

            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];

            ctrlSetText [1610, "Repair"];
            if ((damage _building) isEqualTo 1) then {
                ctrlEnable [1610, true];
            } else {
                ctrlEnable [1610, false];
            };

            // BO: Garage button -- visible only when at an owned warehouse.
            // Right-column bottom slot.
            private _ownedList = warehouse getVariable ["owned", []];
            if (_building in _ownedList) then {
                private _disp = findDisplay 8001;
                if (!isNull _disp) then {
                    private _btnGarage = _disp ctrlCreate ["RscOverthrowButton", 1657];
                    _btnGarage ctrlSetText "Garage";
                    _btnGarage ctrlSetPosition [
                        safeZoneX + 0.881562 * safeZoneW,
                        safeZoneY + 0.918 * safeZoneH,
                        0.113437 * safeZoneW,
                        0.044 * safeZoneH
                    ];
                    _btnGarage ctrlSetTooltip "Open the persistent garage at this warehouse";
                    _btnGarage setVariable ["BO_garageWh", _building];
                    _btnGarage ctrlAddEventHandler ["ButtonClick", {
                        params ["_c"];
                        private _wh = _c getVariable ["BO_garageWh", objNull];
                        closeDialog 0;
                        [{ params ["_w"]; [_w] spawn BO_fnc_garageDialog }, [_wh], 0.3] call CBA_fnc_waitAndExecute;
                    }];
                    _btnGarage ctrlCommit 0;
                };
            };

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>Warehouse</t><br/>
				<t align='left' size='0.65'>Owned by %1</t><br/>
				<t align='left' size='0.65'>Damage: %2%3</t>
			",
                _ownername,
                round ((damage _building) * 100),
                "%"
            ];
        };

        if (_owner isEqualTo getPlayerUID player) then {
            private _leased = player getVariable ["leased", []];
            private _id = [_building] call OT_fnc_getBuildID;
            if (_id in _leased) then {
                _ownername = format ["%1 (Leased)", _ownername];
            };

            if (_cls isEqualTo OT_item_Tent) exitWith {
                ctrlSetText [1608, "Sell"];
                ctrlEnable [1608, false];
                ctrlEnable [1609, false];
                ctrlEnable [1610, false];

                _buildingTxt = format [
                    "
					<t align='left' size='0.8'>Camp</t><br/>
					<t align='left' size='0.65'>Owned by %1</t>
				",
                    _ownername
                ];
            };

            ctrlSetText [1608, format ["Sell ($%1)", [_sell, 1, 0, true] call CBA_fnc_formatNumber]];

            if (_id in _leased) then {
                ctrlEnable [1609, false];
                ctrlEnable [1610, false];
            };
            if (damage _building isEqualTo 1) then {
                _lease = 0;
            };
            _buildingTxt = format [
                "
				<t align='left' size='0.8'>%1</t><br/>
				<t align='left' size='0.65'>Owned by %2</t><br/>
				<t align='left' size='0.65'>Lease Value: $%3/6hrs</t><br/>
				<t align='left' size='0.65'>Damage: %4%5</t>
			",
                _name,
                _ownername,
                [_lease, 1, 0, true] call CBA_fnc_formatNumber,
                round ((damage _building) * 100),
                "%"
            ];
        } else {
            ctrlEnable [1608, false];
            ctrlEnable [1609, false];
            ctrlEnable [1610, false];
            if (_cls isEqualTo OT_item_Tent) then {
                _name = "Camp";
            };
            if (_cls isEqualTo OT_flag_IND) then {
                _name = _building getVariable "name";
            };
            _buildingTxt = format [
                "
				<t align='left' size='0.8'>%1</t><br/>
				<t align='left' size='0.65'>Owned by %2</t><br/>
				<t align='left' size='0.65'>Damage: %3%4</t>
			",
                _name,
                _ownername,
                round ((damage _building) * 100),
                "%"
            ];
        };
        if (_cls isEqualTo OT_barracks) then {
            _owner = _building call OT_fnc_getOwner;
            _ownername = players_NS getVariable format ["name%1", _owner];
            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];
            ctrlEnable [1609, true];
            ctrlSetText [1609, "Recruit"];
            //ctrlEnable [1609,false];
            //ctrlEnable [1610,false];

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>Barracks</t><br/>
				<t align='left' size='0.65'>Built by %1</t><br/>
				<t align='left' size='0.65'>Damage: %2%3</t>
			",
                _ownername,
                round ((damage _building) * 100),
                "%"
            ];
        };
        if (_cls isEqualTo OT_trainingCamp) then {
            _owner = _building call OT_fnc_getOwner;
            _ownername = players_NS getVariable format ["name%1", _owner];
            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];
            ctrlEnable [1609, true];
            ctrlSetText [1609, "Recruit"];
            //ctrlEnable [1609,false];
            ctrlEnable [1610, false];

            // BO: Training Camp manages per-player recruit loadouts.
            // Inject a right-column button so the action is anchored
            // to the building, not to the always-on Y menu list.
            private _disp = findDisplay 8001;
            if (!isNull _disp) then {
                private _btn = _disp ctrlCreate ["RscOverthrowButton", 1652];
                _btn ctrlSetText "Loadout Templates";
                _btn ctrlSetPosition [
                    safeZoneX + 0.881562 * safeZoneW,
                    safeZoneY + 0.808 * safeZoneH,
                    0.113437 * safeZoneW,
                    0.044 * safeZoneH
                ];
                _btn ctrlSetTooltip "Manage your custom recruit loadouts, copy from another player, reset to default";
                _btn ctrlAddEventHandler ["ButtonClick", {
                    closeDialog 0;
                    [] spawn BO_fnc_loadoutTemplatesDialog;
                }];
                _btn ctrlCommit 0;
            };

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>Training Camp</t><br/>
				<t align='left' size='0.65'>Built by %1</t><br/>
				<t align='left' size='0.65'>Damage: %2%3</t>
			",
                _ownername,
                round ((damage _building) * 100),
                "%"
            ];
        };

        if (_cls isEqualTo OT_refugeeCamp) then {
            _owner = _building call OT_fnc_getOwner;
            _ownername = players_NS getVariable format ["name%1", _owner];
            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];
            ctrlEnable [1609, true];
            ctrlSetText [1609, "Recruit"];
            ctrlEnable [1610, false];

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>Refugee Camp</t><br/>
				<t align='left' size='0.65'>Built by %1</t><br/>
				<t align='left' size='0.65'>Damage: %2%3</t>
			",
                _ownername,
                round ((damage _building) * 100),
                "%"
            ];
        };

        if (_cls isEqualTo OT_flag_IND) then {
            private _base = [];
            {
                if ((_x select 0) distance _building < 5) exitWith { _base = _x };
            } forEach (server getVariable ["bases", []]);

            _ownername = players_NS getVariable [format ["name%1", _base select 2], ""];
            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];
            ctrlEnable [1621, true];
            ctrlEnable [1609, false];
            //ctrlEnable [1609,false];
            ctrlEnable [1610, true];

            // BO: FOB-anchored "FOB Jobs" entry. Lives in the right
            // column alongside Garrison and Set Home -- only when the
            // player is at a base flag, since the missions are
            // dispatched from the FOB itself.
            private _disp = findDisplay 8001;
            if (!isNull _disp) then {
                private _btn = _disp ctrlCreate ["RscOverthrowButton", 1651];
                _btn ctrlSetText "FOB Jobs";
                _btn ctrlSetPosition [
                    safeZoneX + 0.881562 * safeZoneW,
                    safeZoneY + 0.808 * safeZoneH,
                    0.113437 * safeZoneW,
                    0.044 * safeZoneH
                ];
                _btn ctrlSetTooltip "Request a mission from the FOB pool";
                _btn ctrlAddEventHandler ["ButtonClick", {
                    closeDialog 0;
                    // RULE 0: no hint -- fobJobsDialog notifies via
                    // OT_fnc_notifyMinor for every observable outcome
                    // and the immediate hint was being clobbered by it
                    // ~300ms later anyway.
                    // closeDialog defers teardown to end of frame;
                    // the openable-dialog flag stays "occupied"
                    // until then. waitAndExecute pushes the
                    // fobJobsDialog call past at least one frame
                    // boundary -- works from inside a UI event
                    // handler where plain spawn can still race the
                    // same-frame dialog state.
                    [{ [] call BO_fnc_fobJobsDialog }, [], 0.3] call CBA_fnc_waitAndExecute;
                }];
                _btn ctrlCommit 0;

                // BO: Rename button -- sits in the slot right below
                // FOB Jobs and opens the input dialog with the FOB's
                // current name. Visible only to the FOB's owner or
                // a General (the function re-checks ownership).
                private _btnRename = _disp ctrlCreate ["RscOverthrowButton", 1655];
                _btnRename ctrlSetText "Rename";
                _btnRename ctrlSetPosition [
                    safeZoneX + 0.881562 * safeZoneW,
                    safeZoneY + 0.863 * safeZoneH,
                    0.113437 * safeZoneW,
                    0.044 * safeZoneH
                ];
                _btnRename ctrlSetTooltip "Rename this FOB";
                _btnRename ctrlAddEventHandler ["ButtonClick", {
                    closeDialog 0;
                    [] call BO_fnc_renameFOB;
                }];
                _btnRename ctrlCommit 0;
            };

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>%1</t><br/>
				<t align='left' size='0.65'>Founded by %2</t>
			",
                _base select 1,
                _ownername
            ];
        };

        if (damage _building isEqualTo 1) then {
            if ((_owner isEqualTo getPlayerUID player) || (call OT_fnc_playerIsGeneral)) then {
                ctrlEnable [1608, false]; //Not allowed to sell
                ctrlSetText [1609, "Repair"]; //Replace lease/manage with repair
                ctrlEnable [1609, true];
                ctrlEnable [1610, false];
            };
        };
    } else {
        if ((_cls) in OT_allRepairableRuins) then {
            ctrlEnable [1608, false];
            ctrlEnable [1609, false];
            ctrlSetText [1610, "Repair"];
            ctrlEnable [1610, true];

            _buildingTxt = "<t align='left' size='0.8'>Ruins</t><br/>";
        } else {
            if (isNil "_price") then {
                ctrlEnable [1608, false];
                ctrlEnable [1609, false];
                ctrlEnable [1610, false];
            } else {
                ctrlSetText [1608, format ["Buy ($%1)", [_price, 1, 0, true] call CBA_fnc_formatNumber]];
                ctrlEnable [1609, false];
                ctrlEnable [1610, false];

                _buildingTxt = format [
                    "
					<t align='left' size='0.8'>%1</t><br/>
					<t align='left' size='0.65'>Lease Value: $%2/6hrs</t>
				",
                    _name,
                    [_lease, 1, 0, true] call CBA_fnc_formatNumber
                ];

                if (_cls isEqualTo OT_barracks) then {
                    ctrlSetText [1608, "Sell"];
                    ctrlEnable [1608, false];
                    ctrlEnable [1609, false];
                    ctrlEnable [1610, false];

                    _buildingTxt = format [
                        "
						<t align='left' size='0.8'>Barracks</t><br/>
					"
                    ];
                };
            };
        };
    };

    if (_cls isEqualTo OT_policeStation) then {
        private _owner = _building call OT_fnc_getOwner;
        if (!isNil "_owner") then {
            private _ownername = players_NS getVariable format ["name%1", _owner];
            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];
            ctrlSetText [1609, "Manage"];
            ctrlEnable [1609, true];
            //ctrlEnable [1610,false];

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>Police Station</t><br/>
				<t align='left' size='0.65'>Built by %1</t>
			",
                _ownername
            ];
        };
    };

    if (_cls isEqualTo "Land_Cargo_House_V4_F") then {
        private _owner = _building call OT_fnc_getOwner;
        if (!isNil "_owner") then {
            private _ownername = players_NS getVariable format ["name%1", _owner];
            ctrlSetText [1608, "Sell"];
            ctrlEnable [1608, false];
            ctrlEnable [1609, false];
            //ctrlEnable [1610,false];

            _buildingTxt = format [
                "
				<t align='left' size='0.8'>Workshop</t><br/>
				<t align='left' size='0.65'>Built by %1</t>
			",
                _ownername
            ];
        };
    };

    // Fetch the list of buildable houses
    private _buildableHouses = (OT_Buildables param [9, []]) param [2, []];
    if (!((_cls) in OT_allRealEstate + [OT_flag_IND]) && { !(_cls in _buildableHouses) }) then {
        ctrlEnable [1609, false];
        ctrlEnable [1610, false];
        ctrlEnable [1608, false];
        _lease = 0;
        ctrlSetText [1608, "Buy"];
        _buildingTxt = format [
            "
			<t align='left' size='0.8'>%1</t>
		",
            _name
        ];
    };
} else {
    ctrlEnable [1608, false];
    ctrlEnable [1609, false];
    ctrlEnable [1610, false];
};
private _areaText = "";
private _areatxtctrl = (findDisplay 8001) displayCtrl 1101;
private _ob = player call OT_fnc_nearestObjective;
_ob params ["_obpos", "_obname"];
if (_obpos distance player < 250) then {
    if (_obname in (server getVariable ["NATOabandoned", []])) then {
        _areaText = format [
            "
			<t align='left' size='0.8'>%1</t><br/>
			<t align='left' size='0.65'>Under resistance control</t>
		",
            _obname
        ];
        ctrlEnable [1620, true];
        ctrlEnable [1621, true];
    } else {
        _areaText = format [
            "
			<t align='left' size='0.8'>%1</t><br/>
			<t align='left' size='0.65'>Under NATO control</t>
		",
            _obname
        ];
        ctrlEnable [1620, false];
        ctrlEnable [1621, false];
    };
} else {
    private _ob = player call OT_fnc_nearestLocation;
    if ((_ob select 1) isEqualTo "Business") then {
        _obpos = (_ob select 2) select 0;
        _obname = (_ob select 0);

        if (_obpos distance player < 250) then {
            if (_obname in (server getVariable ["GEURowned", []])) then {
                ctrlSetText [1201, "\A3\ui_f\data\map\markers\flags\Tanoa_ca.paa"];
                _areaText = format [
                    "
					<t align='left' size='0.8'>%1</t><br/>
					<t align='left' size='0.65'>Operational</t><br/>
					<t align='left' size='0.65'>(see resistance screen)</t><br/>
				",
                    _obname
                ];
                ctrlEnable [1620, false];
                ctrlEnable [1621, false];
            } else {
                private _price = _obname call OT_fnc_getBusinessPrice;
                ctrlSetText [1201, "\overthrow_main\ui\closed.paa"];
                _areaText = format [
                    "
					<t align='left' size='0.8'>%1</t><br/>
					<t align='left' size='0.65'>Out Of Operation</t><br/>
					<t align='left' size='0.65'>$%2</t>
				",
                    _obname,
                    [_price, 1, 0, true] call CBA_fnc_formatNumber
                ];
                ctrlSetText [1620, "Buy"];
                ctrlEnable [1621, false];
                if (call OT_fnc_playerIsGeneral) then {
                    ctrlEnable [1620, true];
                } else {
                    ctrlEnable [1620, false];
                };
            };
        };
    } else {
        // Multi-factory: locate the nearest OT_factory object so the
        // area UI fires for ANY placed factory, not just the starter
        // site at OT_factoryPos. Pin into _nearbyFactory so the
        // Replace Crate handler closure can scope to a specific
        // factory rather than the global starter.
        private _nearbyFactory = (getPosATL player) nearestObject OT_factory;
        private _nearbyFactoryDist = if (isNull _nearbyFactory) then { 1e6 } else { player distance _nearbyFactory };
        if (_nearbyFactoryDist < 150) then {
            _obname = "Factory";
            if (_obname in (server getVariable ["GEURowned", []])) then {
                _areaText = format [
                    "
					<t align='left' size='0.8'>%1</t><br/>
					<t align='left' size='0.65'>Operational</t>
				",
                    _obname
                ];
                ctrlEnable [1620, true];
                ctrlSetText [1620, "Manage"];
                ctrlEnable [1621, false];

                // BO: Replace Crate button -- spawn a new input crate
                // at a clear spot, transfer cargo from the old one if
                // it's still alive, then delete the old one. Useful
                // when the original crate landed somewhere awkward
                // (inside the building, blocked by props, etc.).
                //
                // Right-column y = 0.918 (bottom slot) -- Rename FOB
                // takes the y = 0.863 slot when at a FOB, so the
                // factory button goes below it. Player at both a FOB
                // and a factory sees FOB Jobs / Rename FOB / Replace
                // Crate stacked top-to-bottom with no overlap.
                private _disp = findDisplay 8001;
                if (!isNull _disp) then {
                    private _btn = _disp ctrlCreate ["RscOverthrowButton", 1654];
                    _btn ctrlSetText "Replace Crate";
                    _btn ctrlSetPosition [
                        safeZoneX + 0.881562 * safeZoneW,
                        safeZoneY + 0.918 * safeZoneH,
                        0.113437 * safeZoneW,
                        0.044 * safeZoneH
                    ];
                    _btn ctrlSetTooltip "Spawn a new input crate at a clear spot and transfer cargo from the old one";
                    // Multi-factory: capture the nearby factory object
                    // into the button's namespaced variable so the
                    // click handler routes Replace Crate to THIS
                    // specific factory, not whatever the legacy
                    // OT_factoryPos points at.
                    _btn setVariable ["BO_factoryObj", _nearbyFactory];
                    _btn ctrlAddEventHandler ["ButtonClick", {
                        params ["_ctrl"];
                        private _factoryObj = _ctrl getVariable ["BO_factoryObj", objNull];
                        closeDialog 0;
                        ["Factory", _factoryObj] remoteExec ["BO_fnc_replaceStructureCrate", 2, false];
                    }];
                    _btn ctrlCommit 0;
                };
            } else {
                private _price = _obname call OT_fnc_getBusinessPrice;
                _areaText = format [
                    "
					<t align='left' size='0.8'>%1</t><br/>
					<t align='left' size='0.65'>Out Of Operation</t><br/>
					<t align='left' size='0.65'>$%2</t>
				",
                    _obname,
                    [_price, 1, 0, true] call CBA_fnc_formatNumber
                ];
                ctrlSetText [1620, "Buy"];
                ctrlEnable [1621, false];
                if (call OT_fnc_playerIsGeneral) then {
                    ctrlEnable [1620, true];
                } else {
                    ctrlEnable [1620, false];
                };
            };
        } else {
            private _base = player call OT_fnc_nearestBase;
            if !(isNil "_base" && { (_base select 0) distance player < 100 }) then {
                ctrlEnable [1621, true];
            } else {
                ctrlEnable [1621, false];
            };
            ctrlEnable [1620, false];
        };
    };
};

// BO world demand events: append a yellow "Demand event" line to the
// area block when the player's nearest town has an active event.
private _evtNearestTown = player call OT_fnc_nearestTown;
private _bo_activeEvents = server getVariable ["BO_activeWorldEvents", []];
{
    _x params [
        ["_eTown", "", [""]],
        ["_eType", "", [""]],
        ["_eStart", [], [[]]],
        ["_eEnd",   [], [[]]],
        ["_eItems", [], [[]]],
        ["_eMul", 1, [0]]
    ];
    if (_eTown isEqualTo _evtNearestTown) then {
        private _dname = _eType;
        {
            if ((_x select 0) isEqualTo _eType) exitWith { _dname = _x select 1 };
        } forEach (missionNamespace getVariable ["BO_eventCatalog", []]);
        _areaText = _areaText + format [
            "<br/><t align='left' size='0.65' color='#FFDD33'>Demand event: %1 (x%2)</t>",
            _dname, _eMul
        ];
    };
} forEach _bo_activeEvents;

_areatxtctrl ctrlSetStructuredText parseText _areaText;

OT_interactingWith = objNull;
_buildingtextctrl ctrlSetStructuredText parseText _buildingTxt;

private _notifytxtctrl = (findDisplay 8001) displayCtrl 1150;

private _notifications = [];
private _opacityList = ["FF", "EF", "DF", "CF", "BF", "AF", "9F", "8F", "7F", "6F", "5F", "4F", "3F", "2F", "1F", "0F"];
for "_x" from 0 to (count OT_notifyHistory - 1) do {
    // Notifications are retreived back to front because the latest one is at the back
    _notifications pushBack (format ["<t size='0.7' align='left' color='#%1FFFFFF'>%2</t>", _opacityList select _x, OT_notifyHistory select (-1 - _x)]);
};

private _txt = _notifications joinString "<br/>";
_notifytxtctrl ctrlSetStructuredText parseText _txt;

// =====================================================================
// BO: runtime-injected Y-menu buttons.
//
// OT ships OT_dialog_main as part of a precompiled config.bin, so we
// can't add buttons via .hpp source. ctrlCreate against the live
// display does the job; buttons auto-destroy with the dialog on close.
//
// Audit Log is global (any player, any location) -- it gets a fixed
// left-column slot directly under OT's Options button.
//
// FOB Jobs and Loadout Templates are *building-context* buttons --
// they're injected from inside the OT_flag_IND and OT_trainingCamp
// branches earlier in this file, so they only show up when the player
// is actually near that building.
// =====================================================================
private _disp = findDisplay 8001;
if (!isNull _disp) then {
    // OT's Options button (IDC 1612) is hardcoded at y=0.885 in the
    // compiled config. We move it to y=0.918 every time the menu
    // opens so it sits below the BO entries and doesn't visually
    // overlap them.

    // Left column layout (BO additions, top-to-bottom):
    //   y = 0.808 : Logistics
    //   y = 0.863 : Recon Flights
    //   y = 0.918 : Options (OT, runtime-repositioned)
    //
    // Audit Log moved out of this column into the Options dialog (Esc
    // -> Options -> Audit Log) so it doesn't share a row with Recon
    // Flights. The injection lives in bo_additions/ui/build_extension.hpp
    // as a config-merge extension to OT_dialog_options.

    private _btnLog = _disp ctrlCreate ["RscOverthrowButton", 1653];
    _btnLog ctrlSetText "Logistics";
    _btnLog ctrlSetPosition [
        safeZoneX + 0.005 * safeZoneW,
        safeZoneY + 0.808 * safeZoneH,
        0.149531 * safeZoneW,
        0.044 * safeZoneH
    ];
    _btnLog ctrlSetTooltip "View routes and active deliveries; create new routes between tagged cargo containers";
    _btnLog ctrlAddEventHandler ["ButtonClick", {
        closeDialog 0;
        [] spawn BO_fnc_logisticsNetworkDialog;
    }];
    _btnLog ctrlCommit 0;

    private _btnRecon = _disp ctrlCreate ["RscOverthrowButton", 1656];
    _btnRecon ctrlSetText "Recon Flights";
    _btnRecon ctrlSetPosition [
        safeZoneX + 0.005 * safeZoneW,
        safeZoneY + 0.863 * safeZoneH,
        0.149531 * safeZoneW,
        0.044 * safeZoneH
    ];
    _btnRecon ctrlSetTooltip "Buy temporary reveal of NATO units in a town, region, or map-wide.";
    _btnRecon ctrlAddEventHandler ["ButtonClick", {
        closeDialog 0;
        [{ [] spawn BO_fnc_reconDialog }, [], 0.3] call CBA_fnc_waitAndExecute;
    }];
    _btnRecon ctrlCommit 0;

    private _btnOptions = _disp displayCtrl 1612;
    if (!isNull _btnOptions) then {
        _btnOptions ctrlSetPosition [
            safeZoneX + 0.005 * safeZoneW,
            safeZoneY + 0.918 * safeZoneH,
            0.149531 * safeZoneW,
            0.044 * safeZoneH
        ];
        _btnOptions ctrlCommit 0;
    };

    // BO: Capture Police Station -- visible only when the player is
    // near a registered, uncaptured NATO police station. Town control
    // state is irrelevant; the station is an independent objective.
    // Top-level conditional (Pattern B, like Replace Crate) so it
    // doesn't depend on which building the player is standing inside.
    private _stations = server getVariable ["BO_natoPoliceStations", []];
    private _nearbyStation = "";
    {
        _x params ["_sTown", "_sPos", "_sCaptured"];
        if (!_sCaptured && {(player distance _sPos) < 30}) exitWith {
            _nearbyStation = _sTown;
        };
    } forEach _stations;

    if (_nearbyStation isNotEqualTo "" && {!(missionNamespace getVariable [format ["BO_polcap_active_%1", _nearbyStation], false])}) then {
        private _btnCap = _disp ctrlCreate ["RscOverthrowButton", 1658];
        _btnCap ctrlSetText "Capture Police Station";
        _btnCap ctrlSetPosition [
            safeZoneX + 0.881562 * safeZoneW,
            safeZoneY + 0.808 * safeZoneH,
            0.113437 * safeZoneW,
            0.044 * safeZoneH
        ];
        _btnCap ctrlSetTooltip format ["Begin capture of the %1 police station -- hold the circle to take it", _nearbyStation];
        _btnCap setVariable ["BO_polcapTown", _nearbyStation];
        _btnCap ctrlAddEventHandler ["ButtonClick", {
            params ["_c"];
            private _town = _c getVariable ["BO_polcapTown", ""];
            closeDialog 0;
            if (_town isNotEqualTo "") then {
                [_town, getPlayerUID player] remoteExec ["BO_fnc_startPoliceStationCapture", 2, false];
            };
        }];
        _btnCap ctrlCommit 0;
    };
};

// =====================================================================