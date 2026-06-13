class OT_dialog_start {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class Background: RscOverthrowStructuredText {
            idc = 1100;
            x = "0.381406 * safeZoneW + safeZoneX";
            y = "0.137 * safeZoneH + safeZoneY";
            w = "0.252656 * safeZoneW";
            h = "0.407 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
            colorActive[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            action = "closeDialog 0; createDialog 'OT_dialog_load';";
            text = "Load Previous Save"; //--- ToDo: Localize;
            x = "0.448438 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Continue previous save"; //--- ToDo: Localize;
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            action = "closeDialog 0; createDialog 'OT_dialog_newgame'; call OT_fnc_newGameDialog;";

            text = "New Game"; //--- ToDo: Localize;
            x = "0.448438 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Starts a new game (Please note, saving will overwrite any previous games)"; //--- ToDo: Localize;
        };
        class background_picture: RscOverthrowPicture {
            idc = 1200;
            text = "\overthrow_main\ui\logo_overthrow.paa";
            x = "0.399969 * safeZoneW + safeZoneX";
            y = "0.038 * safeZoneH + safeZoneY";
            w = "0.216563 * safeZoneW";
            h = "0.363 * safeZoneH";
        };
    };
};

class OT_dialog_load {
    idd = 15150;
    movingenable = 0;

    class controlsBackground {
        class background1: RscOverthrowStructuredText {
            idc = -1;
            x = "0.381406 * safeZoneW + safeZoneX";
            y = "0.137 * safeZoneH + safeZoneY";
            w = "0.252656 * safeZoneW";
            h = "0.572 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        class EditBox: RscEditMulti {
            idc = 1400;
            text = "";
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.291 * safeZoneH + safeZoneY";
            w = "0.242344 * safeZoneW";
            h = "0.231 * safeZoneH";
        };
        class LoadNormal: RscOverthrowButton {
            idc = -1;
            x = "0.448438 * safeZoneW + safeZoneX";
            y = "0.621 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Continue previous save"; //--- ToDo: Localize;
            action = "closeDialog 0; [] remoteExec ['OT_fnc_loadGame', 2, false];";
            text = "Load Save (Original)"; //--- ToDo: Localize;
        };
        class LoadString: RscOverthrowButton {
            idc = -1;
            x = "0.448438 * safeZoneW + safeZoneX";
            y = "0.533 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Load string as a save"; //--- ToDo: Localize;
            // Read save string BEFORE closing dialog — closeDialog wipes the control so ctrlText would return "" and wipe player state
            action = "private _data = parseSimpleArray ctrlText ((findDisplay 15150) displayCtrl 1400); closeDialog 0; [_data] remoteExec ['OT_fnc_loadGame', 2, false];";
            text = "Import Save"; //--- ToDo: Localize;
        };
        class Logo_Picture: RscOverthrowPicture {
            idc = -1;
            text = "\overthrow_main\ui\logo_overthrow.paa";
            x = "0.399969 * safeZoneW + safeZoneX";
            y = "0.038 * safeZoneH + safeZoneY";
            w = "0.216563 * safeZoneW";
            h = "0.363 * safeZoneH";
        };
    };
};

class OT_dialog_vehicle {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////
        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            action = "closeDialog 0; [] spawn OT_fnc_fastTravel;";
            tooltip = "Fast travels this vehicle and it's occupants"; //--- ToDo: Localize;

            text = "Fast Travel"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.126 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        class RscButton_1614: RscOverthrowButton {
            idc = 1614;
            action = "closeDialog 0; [player] spawn OT_fnc_recover;";
            tooltip = "Loot bodies within 150m"; //--- ToDo: Localize;

            text = "Loot"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.214 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        class RscButton_1613: RscOverthrowButton {
            idc = 1613;
            text = "Jobs"; //--- ToDo: Localize;
            action = "call OT_fnc_jobsDialog";

            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.302 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";

        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Transfer From"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.478 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Transfers the contents of the closest container into this vehicle"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_transferFrom;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Transfer To"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.390 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Transfers the contents of this vehicle into the closest container"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_transferTo;";
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            text = "Transfer Legit"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.566 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Transfers only legal (sellable) items from the closest container into this vehicle"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_transferLegit;";
        };
        class RscButton_1604: RscOverthrowButton {
            idc = 1604;
            text = "Take Legit"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.654 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Takes legal (sellable) items from the vehicle into your inventory"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_takeLegit;";
        };
        class RscButton_1605: RscOverthrowButton {
            idc = 1605;
            text = "Lock Vehicle"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.742 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Locks this car so only you can drive it or access it's inventory"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_lockVehicle;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_vehiclewarehouse {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Fast Travel"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.39 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "closeDialog 0; [] spawn OT_fnc_fastTravel;";
            tooltip = "Fast travels this vehicle and it's occupants"; //--- ToDo: Localize;
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Take From"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.654 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Take from the warehouse"; //--- ToDo: Localize;
            action = "closeDialog 0; createDialog 'OT_dialog_warehouse'; [] call OT_fnc_warehouseDialog;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Store All"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.478 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Stores the contents of this vehicle in the warehouse"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_storeAll;";
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            text = "Transfer Legit"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.566 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Takes all legal (sellable) items from the warehouse"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_transferLegit;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_vehicleport {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Fast Travel"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.39 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "closeDialog 0; [] spawn OT_fnc_fastTravel;";
            tooltip = "Fast travels this vehicle and it's occupants"; //--- ToDo: Localize;
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Import"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.654 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Import items from the global market"; //--- ToDo: Localize;
            action = "closeDialog 0; createDialog 'OT_dialog_import'; [] call OT_fnc_importDialog;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Export All"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.566 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Exports the contents of this vehicle"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_exportAll;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_vehiclehardware {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Fast Travel"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.39 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "closeDialog 0; [] spawn OT_fnc_fastTravel;";
            tooltip = "Fast travels this vehicle and it's occupants"; //--- ToDo: Localize;
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Buy"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.654 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Buy from this hardware store"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_buyHardwareDialog;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Sell"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.566 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Sell to this hardware store"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_sellHardwareDialog;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_vehiclestore {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Fast Travel"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.39 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "closeDialog 0; [] spawn OT_fnc_fastTravel;";
            tooltip = "Fast travels this vehicle and it's occupants"; //--- ToDo: Localize;
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Buy"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.654 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Buy from this store"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_buyDialogVehicle;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Sell"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.566 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Sell to this store"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_sellDialogVehicle;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_command {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////
        class RscButton_1604: RscOverthrowButton {
            idc = 1604;
            text = "Open Arsenal"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.236 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Commands first unit selected to walk to and open the closest ammobox arsenal, uses warehouse if ammobox is at a warehouse"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_orderOpenArsenal;";
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Loot"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Commands all selected units to loot bodies and fill closest container to them"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_orderLoot;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Open Inventory"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.324 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Commands first unit selected to open inventory"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_orderOpenInventory;";
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            text = "Create Squad"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.5 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Splits selected units off into a new squad"; //--- ToDo: Localize;
            action = "closeDialog 0; [] spawn OT_fnc_createSquad;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_squad {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Xeqozy)
        ////////////////////////////////////////////////////////

        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Assign Vehicle"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.324 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Assigns vehicle you are looking at to squad"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_squadAssignVehicle;";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Get In"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Orders squad to board assigned vehicle"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_squadGetIn;";
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            text = "Get Out"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.5 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Orders squad to disembark vehicle"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_squadGetOut;";
        };
        class RscButton_1604: RscOverthrowButton {
            idc = 1604;
            text = "Get In My Vehicle"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.588 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Orders squad to board your vehicle"; //--- ToDo: Localize;
            action = "closeDialog 0; [] call OT_fnc_squadGetInMyVehicle;";
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.885 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.066 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////

    };
};

class OT_dialog_options {
    idd = -1;
    movingenable = 0;

    class controls {
        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            action = "closeDialog 0; [player] remoteExec ['OT_fnc_saveGame', 2, false];";

            text = "Persistent Save"; //--- ToDo: Localize;
            x = "0.386563 * safeZoneW + safeZoneX";
            y = "0.225 * safeZoneH + safeZoneY";
            w = "0.2475 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "A more secure save than default, this will work across updates of both Arma and Overthrow. To load this just restart the mission and choose ""load persistent""."; //--- ToDo: Localize;
        };
        class RscButton_1607: RscOverthrowButton {
            idc = 1607;
            action = "[] remoteExec ['OT_fnc_autoSaveToggle', 2];";
            text = "Autosave Toggle"; //--- ToDo: Localize;
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Toggle between (0/5/10/15/30/45/60) minute autosaves.\n0 will disable autosaving!"; //--- ToDo: Localize;
        };
        class RscButton_1608: RscOverthrowButton {
            idc = 1608;
            action = "[] remoteExec ['OT_fnc_autoloadToggle', 2]";
            text = "Toggle Autoloading"; //--- ToDo: Localize;
            x = "0.515469 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Autoload mission if on a dedicated server";
        };

        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            action = "OT_spawnCivPercentage = OT_spawnCivPercentage - 0.01; if (OT_spawnCivPercentage < 0) then { OT_spawnCivPercentage = 0 }; publicVariable 'OT_spawnCivPercentage'; hint format ['Civilian spawn now at %1%2', OT_spawnCivPercentage * 100, '%'];";

            text = "Civ % --"; //--- ToDo: Localize;
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.511 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Decreases the amount of civilians that spawn in towns"; //--- ToDo: Localize;
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            action = "OT_spawnCivPercentage = OT_spawnCivPercentage + 0.01; if (OT_spawnCivPercentage < 0) then { OT_spawnCivPercentage = 0 }; publicVariable 'OT_spawnCivPercentage'; hint format ['Civilian spawn now at %1%2', OT_spawnCivPercentage * 100, '%'];";

            text = "Civ % ++"; //--- ToDo: Localize;
            x = "0.515469 * safeZoneW + safeZoneX";
            y = "0.511 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Increases the amount of civilians that spawn in towns"; //--- ToDo: Localize;
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            action = "call OT_fnc_decreaseTax";

            text = "Tax % --"; //--- ToDo: Localize;
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.61 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Decreases the resistance tax rate"; //--- ToDo: Localize;
        };
        class RscButton_1604: RscOverthrowButton {
            idc = 1604;
            action = "call OT_fnc_increaseTax";

            text = "Tax % ++"; //--- ToDo: Localize;
            x = "0.515469 * safeZoneW + safeZoneX";
            y = "0.61 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Increases the resistance tax rate"; //--- ToDo: Localize;
        };
        class RscButton_1605: RscOverthrowButton {
            idc = 1605;
            action = "call OT_fnc_cleanDead;";
            text = "Clean bodies/wrecks"; //--- ToDo: Localize;
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Will completely destroy all dead bodies, wrecks and vehicles that cannot move"; //--- ToDo: Localize;
        };
        class RscButton_1606: RscOverthrowButton {
            idc = 1606;
            action = "[0, 0] remoteExecCall ['setFog', 0, false]";

            text = "Clean fog"; //--- ToDo: Localize;
            x = "0.515469 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.118594 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Clears fog"; //--- ToDo: Localize;
        };
        class RscText_1009: RscOverthrowButton {
            idc = 1609;
            action = "call OT_fnc_toggleZeus;";
            text = "Toggle Zeus"; //--- ToDo: Localize;
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.709 * safeZoneH + safeZoneY";
            w = "0.2475 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Toggle between zeus access as the host"; //--- ToDo: Localize;
        };
    };
};

class OT_dialog_upload {
    idd = 49558;
    movingenable = 0;
    onLoad = "params ['_display']; _display displayAddEventHandler ['KeyDown', { if ((_this select 1) == 1) then { true } }];";

    class controlsBackground {
        class background1: RscOverthrowText {
            idc = -1;
            text = "OVERTHROW MISSION EXPORT"; //--- ToDo: Localize;
            x = "0.29375 * safeZoneW + safeZoneX";
            y = "0.225 * safeZoneH + safeZoneY";
            w = "0.4125 * safeZoneW";
            h = "0.022 * safeZoneH";
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R', 0.77])",
                "(profileNamespace getVariable ['GUI_BCG_RGB_G', 0.51])",
                "(profileNamespace getVariable ['GUI_BCG_RGB_B', 0.08])",
                1
            };
        };
        class background2: RscOverthrowText {
            idc = -1;
            x = "0.29375 * safeZoneW + safeZoneX";
            y = "0.247 * safeZoneH + safeZoneY";
            w = "0.4125 * safeZoneW";
            h = "0.528 * safeZoneH";
            colorBackground[] = {-1, -1, -1, 0.7};
        };
        class background3: RscOverthrowText {
            idc = -1;
            x = "0.298905 * safeZoneW + safeZoneX";
            y = "0.577 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.143 * safeZoneH";
            colorBackground[] = {-1, -1, -1, 0.5};
        };
    };
    class controls {
        class EditBox: RscEdit {
            idc = 1;
            style = 16;
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.258 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.308 * safeZoneH";
            canModify = 0;
            font = "EtelkaMonospacePro";
            colorBackground[] = {-1, -1, -1, 0.75};
        };
        class LegalControlGroup: RscControlsGroup {
            idc = -1;
            x = "0.298905 * safeZoneW + safeZoneX";
            y = "0.577 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.143 * safeZoneH";
            class Controls {
                class LegalText: RscOverthrowStructuredText {
                    idc = 5;
                    x = "0 * safeZoneW";
                    y = "0 * safeZoneH";
                    w = "0.397031 * safeZoneW";
                    h = "0.143 * safeZoneH";
                    text = "";
                    colorBackground[] = {-1, -1, -1, 0};
                };
            };
        };
        class CancelButton: RscOverthrowStructuredText {
            idc = -1;
            text = "<t align='center' font='PuristaBold' color='#FFFFFF'>CLOSE MENU</t>"; //--- ToDo: Localize;
            onMouseButtonClick = "playSound 'click'; closeDialog 0;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.731 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.033 * safeZoneH";
            onMouseEnter = "(_this select 0) ctrlSetStructuredText parseText ""<t align='center' font='PuristaBold' color='#00FF00'>CLOSE MENU</t>""; (_this select 0) ctrlCommit 0.5; ";
            onMouseExit = "(_this select 0) ctrlSetStructuredText parseText ""<t align='center' font='PuristaBold' color='#FFFFFF'>CLOSE MENU</t>""; (_this select 0) ctrlCommit 0.5; ";
            colorBackground[] = {-1, -1, -1, 0.7};
        };
    };
};

class OT_dialog_main {
    idd = 8001;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;

            text = "";
            x = "0 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
        class RscStructuredText_1104: RscOverthrowStructuredText {
            idc = 1104;

            text = "";
            x = "0.876406 * safeZoneW + safeZoneX";
            y = "0 * safeZoneH + safeZoneY";
            w = "0.123759 * safeZoneW";
            h = "1 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Mucomo)
        ////////////////////////////////////////////////////////
        class RscButton_1699: RscOverthrowButton {
            idc = 1699;
            action = "closeDialog 0; [] spawn OT_fnc_mapInfoDialog";

            text = "Map Info"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.247 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Retrieve information on town stability and more"; //--- ToDo: Localize;
        };
        class RscStructuredText_1100: RscOverthrowStructuredText {
            idc = 1100;

            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.302 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.1 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.4};
        };
        class RscStructuredText_1150: RscOverthrowStructuredText {
            idc = 1150;

            x = "0.16 * safeZoneW + safeZoneX";
            y = "0.302 * safeZoneH + safeZoneY";
            w = "0.3 * safeZoneW";
            h = "0.3 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0};
        };
        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            action = "closeDialog 0; [] spawn OT_fnc_fastTravel";

            text = "Fast Travel"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.423 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Instantly travel to various controlled locations"; //--- ToDo: Localize;
        };
        class RscButton_1613: RscOverthrowButton {
            idc = 1613;
            action = "closeDialog 0; [] spawn OT_fnc_resistanceDialog";

            text = "Resistance"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.478 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Manage owned businesses and resistance funds"; //--- ToDo: Localize;
        };
        class RscButton_1614: RscOverthrowButton {
            idc = 1614;
            action = "closeDialog 0; [] spawn OT_fnc_jobsDialog";

            text = "Jobs"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.533 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Jobs and tasks currently available"; //--- ToDo: Localize;
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            action = "closeDialog 0; createDialog 'OT_dialog_place'";

            text = "Place"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.588 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Place smaller items around houses you own or at friendly bases"; //--- ToDo: Localize;
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            action = "closeDialog 0; [] spawn OT_fnc_build";

            text = "Build"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.643 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Build structures in towns and at bases"; //--- ToDo: Localize;
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            action = "[] spawn OT_fnc_manageRecruitsDialog;";

            text = "Manage Recruits"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.698 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Manage recruits in your group"; //--- ToDo: Localize;
        };
        class RscButton_1611: RscOverthrowButton {
            idc = 1611;
            action = "[] spawn OT_fnc_characterSheetDialog;";

            text = "Character Sheet"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.753 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Upgrade your character"; //--- ToDo: Localize;
        };
        class RscButton_1612: RscOverthrowButton {
            idc = 1612;
            action = "call OT_fnc_optionsDialog";

            text = "Options"; //--- ToDo: Localize;
            x = "0.005 * safeZoneW + safeZoneX";
            y = "0.808 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Persistent save, clear bodies/fog and more"; //--- ToDo: Localize;
        };

        class RscButton_1620: RscOverthrowButton {
            idc = 1620;
            action = "closeDialog 0; [] spawn OT_fnc_manageArea";

            text = "Procurement"; //--- ToDo: Localize;
            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.0515625 * safeZoneW";
            h = "0.044 * safeZoneH";
        };
        class RscButton_1621: RscOverthrowButton {
            idc = 1621;
            action = "closeDialog 0; [] call OT_fnc_garrisonDialog";

            text = "Garrison"; //--- ToDo: Localize;
            x = "0.943438 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.0515625 * safeZoneW";
            h = "0.044 * safeZoneH";
        };

        class RscPicture_1201: RscOverthrowPicture {
            idc = 1201;

            text = "#(argb,8,8,3)color(0,0,0,0)";
            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.479 * safeZoneH + safeZoneY";
            w = "0.113437 * safeZoneW";
            h = "0.1 * safeZoneH";
        };
        class RscButton_1608: RscOverthrowButton {
            idc = 1608;
            action = "closeDialog 0; [] call OT_fnc_buyBuilding";

            text = "Buy"; //--- ToDo: Localize;
            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.698 * safeZoneH + safeZoneY";
            w = "0.113437 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Purchase this building"; //--- ToDo: Localize;
        };
        class RscButton_1630: RscOverthrowButton {
            idc = 1630;
            action = "closeDialog 0; [] call OT_fnc_logisticsDialog";

            text = "Vehicles"; //--- ToDo: Localize;
            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.247 * safeZoneH + safeZoneY";
            w = "0.113437 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "List of all military vehicles and their state"; //--- ToDo: Localize;
        };
        class RscButton_1609: RscOverthrowButton {
            idc = 1609;
            action = "closeDialog 0; [] call OT_fnc_leaseBuilding";

            text = "Lease"; //--- ToDo: Localize;
            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.753 * safeZoneH + safeZoneY";
            w = "0.0515625 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Lease this building"; //--- ToDo: Localize;
        };
        class RscButton_1610: RscOverthrowButton {
            idc = 1610;
            action = "closeDialog 0; [] call OT_fnc_setHome";

            text = "Set Home"; //--- ToDo: Localize;
            x = "0.943438 * safeZoneW + safeZoneX";
            y = "0.753 * safeZoneH + safeZoneY";
            w = "0.0515625 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Make this your home (respawn point)"; //--- ToDo: Localize;
        };
        class RscStructuredText_1101: RscOverthrowStructuredText {
            idc = 1101;

            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.302 * safeZoneH + safeZoneY";
            w = "0.113437 * safeZoneW";
            h = "0.1 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.4};
        };
        class RscStructuredText_1102: RscOverthrowStructuredText {
            idc = 1102;

            x = "0.881562 * safeZoneW + safeZoneX";
            y = "0.588 * safeZoneH + safeZoneY";
            w = "0.113437 * safeZoneW";
            h = "0.1 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.4};
        };
        class RscPicture_1200: RscOverthrowPicture {
            idc = 1200;
            text = "\overthrow_main\ui\logo_overthrow.paa";
            x = "0.00499997 * safeZoneW + safeZoneX";
            y = "0.103 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.144 * safeZoneW";
        };
        class RscStructuredText_1106: RscOverthrowStructuredText {
            idc = 1106;

            x = "safeZoneX + (0.8 * safeZoneW)";
            y = "safeZoneY + (0.15 * safeZoneH)";
            w = "0.19 * safeZoneW";
            h = "0.1 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0};
            colorActive[] = {0, 0, 0, 0};
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////
    };
};

class OT_dialog_char {
    idd = 8003;
    movingenable = 0;

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Pejity)
        ////////////////////////////////////////////////////////

        class RscStructuredText_1100: RscOverthrowStructuredText {
            idc = 1100;
            text = ""; //--- ToDo: Localize;
            x = "0.273125 * safeZoneW + safeZoneX";
            y = "0.269 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.143 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.5};
            colorActive[] = {0, 0, 0, 0.5};
        };
        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Increase Level (-10 Influence)"; //--- ToDo: Localize;
            x = "0.273125 * safeZoneW + safeZoneX";
            y = "0.423 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            action = "['fitness'] call buyPerk;";
        };
        class RscStructuredText_1101: RscOverthrowStructuredText {
            idc = 1101;
            text = "Increase Level (-10 Influence)"; //--- ToDo: Localize;
            x = "0.427812 * safeZoneW + safeZoneX";
            y = "0.269 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.143 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.3};
            colorActive[] = {0, 0, 0, 0.3};
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Increase Level (-10 Influence)"; //--- ToDo: Localize;
            x = "0.427812 * safeZoneW + safeZoneX";
            y = "0.423 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            action = "['trade'] call buyPerk;";
        };
        class RscStructuredText_1102: RscOverthrowStructuredText {
            idc = 1102;
            text = ""; //--- ToDo: Localize;
            x = "0.5825 * safeZoneW + safeZoneX";
            y = "0.269 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.143 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.3};
            colorActive[] = {0, 0, 0, 0.3};
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Increase Level (-10 Influence)"; //--- ToDo: Localize;
            x = "0.5825 * safeZoneW + safeZoneX";
            y = "0.423 * safeZoneH + safeZoneY";
            w = "0.149531 * safeZoneW";
            h = "0.044 * safeZoneH";
            action = "['stealth'] call buyPerk;";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////
    };
};

class OT_dialog_tute {
    idd = -1;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1101: RscOverthrowStructuredText {
            idc = 1101;
            x = "0.324687 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.355781 * safeZoneW";
            h = "0.198 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
            colorActive[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Kizeru)
        ////////////////////////////////////////////////////////

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            action = "closeDialog 0; [] spawn OT_fnc_tutorial;";

            text = "Yes"; //--- ToDo: Localize;
            x = "0.340156 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.0721875 * safeZoneW";
            h = "0.088 * safeZoneH";
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            action = "closeDialog 0;";

            text = "No"; //--- ToDo: Localize;
            x = "0.592812 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.0721875 * safeZoneW";
            h = "0.088 * safeZoneH";
        };
        class RscStructuredText_1100: RscOverthrowStructuredText {
            idc = 1100;

            text = "Would you like a quick tutorial? (You will receive free items)"; //--- ToDo: Localize;
            x = "0.340156 * safeZoneW + safeZoneX";
            y = "0.346 * safeZoneH + safeZoneY";
            w = "0.324844 * safeZoneW";
            h = "0.033 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0};
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////
    };
};

class OT_dialog_choose {
    idd = 8002;
    movingenable = 0;

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Humesu)
        ////////////////////////////////////////////////////////

        class RscStructuredText_1100: RscOverthrowStructuredText {
            idc = 1100;
            x = "0.29375 * safeZoneW + safeZoneX";
            y = "0.269 * safeZoneH + safeZoneY";
            w = "0.4125 * safeZoneW";
            h = "0.184 * safeZoneH";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
        };

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Lorem Ipsum dolor sit amet blah blah blah"; //--- ToDo: Localize;
            action = "closeDialog 0; 0 call OT_fnc_choiceMade;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.478 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.055 * safeZoneH";
            sizeEx = "0.017 * safeZoneH";
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Lorem Ipsum dolor sit amet blah blah blah"; //--- ToDo: Localize;
            action = "closeDialog 0; 1 call OT_fnc_choiceMade;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.544 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.055 * safeZoneH";
            sizeEx = "0.017 * safeZoneH";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Lorem Ipsum dolor sit amet blah blah blah"; //--- ToDo: Localize;
            action = "closeDialog 0; 2 call OT_fnc_choiceMade;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.61 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.055 * safeZoneH";
            sizeEx = "0.017 * safeZoneH";
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            text = "Lorem Ipsum dolor sit amet blah blah blah"; //--- ToDo: Localize;
            action = "closeDialog 0; 3 call OT_fnc_choiceMade;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.676 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.055 * safeZoneH";
            sizeEx = "0.017 * safeZoneH";
        };
        class RscButton_1604: RscOverthrowButton {
            idc = 1604;
            text = "Lorem Ipsum dolor sit amet blah blah blah"; //--- ToDo: Localize;
            action = "closeDialog 0; 4 call OT_fnc_choiceMade;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.742 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.055 * safeZoneH";
            sizeEx = "0.017 * safeZoneH";
        };
        class RscButton_1605: RscOverthrowButton {
            idc = 1605;
            text = "Lorem Ipsum dolor sit amet blah blah blah"; //--- ToDo: Localize;
            action = "closeDialog 0; 5 call OT_fnc_choiceMade;";
            x = "0.298906 * safeZoneW + safeZoneX";
            y = "0.808 * safeZoneH + safeZoneY";
            w = "0.402187 * safeZoneW";
            h = "0.055 * safeZoneH";
            sizeEx = "0.017 * safeZoneH";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////
    };
};

class OT_dialog_newgame {
    idd = 8099;
    movingenable = 0;

    class controlsBackground {
        class RscStructuredText_1100: RscOverthrowStructuredText {
            idc = 1100;
            x = "0.324687 * safeZoneW + safeZoneX";
            y = "0.269 * safeZoneH + safeZoneY";
            w = "0.345469 * safeZoneW";
            h = "0.495 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 1};
            colorActive[] = {0.1, 0.1, 0.1, 1};
        };
    };

    class controls {
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT START (by ARMAzac, v1.063, #Zosiwi)
        ////////////////////////////////////////////////////////

        class RscButton_1600: RscOverthrowButton {
            idc = 1600;
            text = "Easy"; //--- ToDo: Localize;
            x = "0.329844 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_difficulty', 0, true]; call OT_fnc_newGameDialog;";
            tooltip = "Recommended for beginners playing solo";
        };
        class RscButton_1601: RscOverthrowButton {
            idc = 1601;
            text = "Normal"; //--- ToDo: Localize;
            x = "0.453594 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_difficulty', 1, true]; call OT_fnc_newGameDialog;";
            color[] = {0, 0.8, 0, 1};
            tooltip = "Recommended for beginners playing in groups or experienced players solo";
        };
        class RscButton_1602: RscOverthrowButton {
            idc = 1602;
            text = "Hard"; //--- ToDo: Localize;
            x = "0.577344 * safeZoneW + safeZoneX";
            y = "0.313 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_difficulty', 2, true]; call OT_fnc_newGameDialog;";
            tooltip = "For the hardcore";
        };
        class RscStructuredText_1101: RscOverthrowStructuredText {
            idc = 1101;
            text = "<t size='1.5'>Difficulty</t>"; //--- ToDo: Localize;
            x = "0.329844 * safeZoneW + safeZoneX";
            y = "0.269 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "0.033 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0};
        };
        class RscStructuredText_1102: RscOverthrowStructuredText {
            idc = 1102;
            text = "<t size='1.5'>Fast Travel</t>"; //--- ToDo: Localize;
            x = "0.329844 * safeZoneW + safeZoneX";
            y = "0.423 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "0.033 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0};
        };
        class RscButton_1603: RscOverthrowButton {
            idc = 1603;
            text = "Free"; //--- ToDo: Localize;
            x = "0.329844 * safeZoneW + safeZoneX";
            y = "0.467 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_fastTravelType', 0, true]; call OT_fnc_newGameDialog;";
            tooltip = "Fast travel will not cost anything";
        };
        class RscButton_1604: RscOverthrowButton {
            idc = 1604;
            text = "Costs"; //--- ToDo: Localize;
            x = "0.453594 * safeZoneW + safeZoneX";
            y = "0.467 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            color[] = {0, 0.8, 0, 1};
            action = "server setVariable ['OT_fastTravelType', 1, true]; call OT_fnc_newGameDialog;";
            tooltip = "Fast travel will cost money";
        };
        class RscButton_1605: RscOverthrowButton {
            idc = 1605;
            text = "Disabled"; //--- ToDo: Localize;
            x = "0.577344 * safeZoneW + safeZoneX";
            y = "0.467 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_fastTravelType', 2, true]; call OT_fnc_newGameDialog;";
            tooltip = "Fast travel will be disabled";
        };
        class RscStructuredText_1103: RscOverthrowStructuredText {
            idc = 1103;
            text = "<t size='1.5'>Fast Travel Rules</t>"; //--- ToDo: Localize;
            x = "0.329844 * safeZoneW + safeZoneX";
            y = "0.577 * safeZoneH + safeZoneY";
            w = "0.159844 * safeZoneW";
            h = "0.033 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0};
        };
        class RscButton_1607: RscOverthrowButton {
            idc = 1607;
            text = "Open"; //--- ToDo: Localize;
            x = "0.329844 * safeZoneW + safeZoneX";
            y = "0.621 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_fastTravelRules', 0, true]; call OT_fnc_newGameDialog;";
            tooltip = "No rules for fast travel";
        };
        class RscButton_1608: RscOverthrowButton {
            idc = 1608;
            text = "No Weapons"; //--- ToDo: Localize;
            x = "0.453594 * safeZoneW + safeZoneX";
            y = "0.621 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            color[] = {0, 0.8, 0, 1};
            action = "server setVariable ['OT_fastTravelRules', 1, true]; call OT_fnc_newGameDialog;";
            tooltip = "Cannot fast travel while holding a weapon or carrying drugs";
        };
        class RscButton_1609: RscOverthrowButton {
            idc = 1609;
            text = "Restricted"; //--- ToDo: Localize;
            x = "0.577344 * safeZoneW + safeZoneX";
            y = "0.621 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            action = "server setVariable ['OT_fastTravelRules', 2, true]; call OT_fnc_newGameDialog;";
            tooltip = "Cannot fast travel while holding a weapon, carrying drugs, or in an offensive vehicle";
        };
        class RscButton_1606: RscOverthrowButton {
            idc = 1606;
            text = "Start Game"; //--- ToDo: Localize;
            x = "0.577344 * safeZoneW + safeZoneX";
            y = "0.708 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.045 * safeZoneH";
            action = "closeDialog 0; [] remoteExec ['OT_fnc_newGame', 2, false]";
        };
        ////////////////////////////////////////////////////////
        // GUI EDITOR OUTPUT END
        ////////////////////////////////////////////////////////
    };
};
