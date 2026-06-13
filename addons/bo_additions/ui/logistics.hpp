/*
 * logistics.hpp -- bo_additions
 *
 * UI for the Better Overthrow logistics network.
 *
 *   BO_dialog_logistics      (IDD 8050) -- main two-tab dialog
 *                                          (Routes + Active Deliveries)
 *   BO_dialog_logisticsRoute (IDD 8051) -- create / edit a route,
 *                                          with schedule editor
 *
 * Pattern: bare redeclaration -- no forward decls of dialog classes
 * themselves, only of the OT base controls that BO inherits from.
 * Same pattern as build_extension.hpp; see
 * [[hemtt-class-extension]] memory for the rationale.
 *
 * IDC ranges (BO-reserved 1500-1999, mirroring OT's IDC tiers):
 *
 *   1100 - structured text (preview / status lines)
 *   1400-1499 - edit / combo (form inputs)
 *   1500-1599 - listboxes
 *   1600-1699 - primary buttons (Close, Save, etc.)
 *   1610-1614 - action row (Create / Edit / Delete / Pause / Dispatch)
 *   1620-1622 - schedule mode buttons
 *   1623 - skip-if-empty toggle
 *   1630-1635 - interval presets
 *   1640-1641 - save / cancel
 *   1700+ - already used by End Early + Factory build extension
 */

// RscOverthrowButton is forward-declared in build_extension.hpp.
// Both files are #included at root from config.cpp, so a second
// forward decl here would trip hemtt's L-C03.
class RscOverthrowStructuredText;
class RscOverthrowListBox;
class RscOverthrowEdit;
class RscOverthrowCombo;

// ---------------------------------------------------------------------
// BO_dialog_logistics -- the main viewer
// ---------------------------------------------------------------------

class BO_dialog_logistics {
    idd = 8050;
    movingenable = 0;
    onLoad = "uiNamespace setVariable ['BO_dialog_logistics', _this select 0]";
    onUnload = "uiNamespace setVariable ['BO_dialog_logistics', displayNull]";

    class controlsBackground {
        // Dark panel behind everything
        class Bg: RscOverthrowStructuredText {
            idc = 1199;
            text = "";
            x = "0.18 * safeZoneW + safeZoneX";
            y = "0.10 * safeZoneH + safeZoneY";
            w = "0.64 * safeZoneW";
            h = "0.80 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 0.95};
        };
    };

    class controls {
        // Title bar
        class Title: RscOverthrowStructuredText {
            idc = 1100;
            text = "<t size='1.5' align='center'>LOGISTICS NETWORK</t>";
            x = "0.18 * safeZoneW + safeZoneX";
            y = "0.12 * safeZoneH + safeZoneY";
            w = "0.64 * safeZoneW";
            h = "0.04 * safeZoneH";
        };

        // Close button
        class CloseBtn: RscOverthrowButton {
            idc = 1600;
            action = "closeDialog 0";
            text = "Close";
            x = "0.74 * safeZoneW + safeZoneX";
            y = "0.12 * safeZoneH + safeZoneY";
            w = "0.07 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // Tab: Routes
        class TabRoutes: RscOverthrowButton {
            idc = 1601;
            action = "['routes'] call BO_fnc_logisticsNetworkDialog";
            text = "Routes";
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.18 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // Tab: Active
        class TabActive: RscOverthrowButton {
            idc = 1602;
            action = "['active'] call BO_fnc_logisticsNetworkDialog";
            text = "Active";
            x = "0.305 * safeZoneW + safeZoneX";
            y = "0.18 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // Routes listbox
        class ListRoutes: RscOverthrowListBox {
            idc = 1500;
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.225 * safeZoneH + safeZoneY";
            w = "0.60 * safeZoneW";
            h = "0.55 * safeZoneH";
            sizeEx = 0.03;
        };

        // Active listbox (hidden initially)
        // Match ListRoutes height so the panel doesn't visibly resize on tab switch.
        class ListActive: RscOverthrowListBox {
            idc = 1501;
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.225 * safeZoneH + safeZoneY";
            w = "0.60 * safeZoneW";
            h = "0.55 * safeZoneH";
            sizeEx = 0.03;
        };

        // Action row (Routes tab only)
        class ActCreate: RscOverthrowButton {
            idc = 1610;
            action = "['create', -1] call BO_fnc_logisticsRouteDialog";
            text = "Create";
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.80 * safeZoneH + safeZoneY";
            w = "0.11 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
        class ActEdit: RscOverthrowButton {
            idc = 1611;
            action = "['edit', lbCurSel 1500] call BO_fnc_logisticsRouteDialog";
            text = "Edit";
            x = "0.315 * safeZoneW + safeZoneX";
            y = "0.80 * safeZoneH + safeZoneY";
            w = "0.11 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
        // Destructive + rolls back in-flight deliveries; require Yes/No confirm via OT_fnc_playerDecision.
        class ActDelete: RscOverthrowButton {
            idc = 1612;
            action = "['deleteConfirm', lbCurSel 1500] call BO_fnc_logisticsNetworkDialog";
            text = "Delete";
            x = "0.43 * safeZoneW + safeZoneX";
            y = "0.80 * safeZoneH + safeZoneY";
            w = "0.11 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
        class ActPause: RscOverthrowButton {
            idc = 1613;
            action = "['pause', lbCurSel 1500] call BO_fnc_logisticsNetworkDialog";
            text = "Pause / Resume";
            x = "0.545 * safeZoneW + safeZoneX";
            y = "0.80 * safeZoneH + safeZoneY";
            w = "0.13 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
        class ActDispatch: RscOverthrowButton {
            idc = 1614;
            action = "['dispatch', lbCurSel 1500] call BO_fnc_logisticsNetworkDialog";
            text = "Dispatch Now";
            x = "0.68 * safeZoneW + safeZoneX";
            y = "0.80 * safeZoneH + safeZoneY";
            w = "0.12 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
    };
};

// ---------------------------------------------------------------------
// BO_dialog_logisticsRoute -- create / edit one route
// ---------------------------------------------------------------------

class BO_dialog_logisticsRoute {
    idd = 8051;
    movingenable = 0;
    onLoad = "uiNamespace setVariable ['BO_dialog_logisticsRoute', _this select 0]";
    onUnload = "uiNamespace setVariable ['BO_dialog_logisticsRoute', displayNull]";

    class controlsBackground {
        class Bg: RscOverthrowStructuredText {
            idc = 1199;
            text = "";
            x = "0.25 * safeZoneW + safeZoneX";
            y = "0.12 * safeZoneH + safeZoneY";
            w = "0.50 * safeZoneW";
            h = "0.76 * safeZoneH";
            colorBackground[] = {0.1, 0.1, 0.1, 0.95};
        };
    };

    class controls {
        class Title: RscOverthrowStructuredText {
            idc = 1100;
            text = "<t size='1.4' align='center'>CREATE ROUTE</t>";
            x = "0.25 * safeZoneW + safeZoneX";
            y = "0.14 * safeZoneH + safeZoneY";
            w = "0.50 * safeZoneW";
            h = "0.04 * safeZoneH";
        };

        // Source label + combo
        class LblSrc: RscOverthrowStructuredText {
            idc = 1101;
            text = "<t>Source</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.20 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class CmbSrc: RscOverthrowCombo {
            idc = 1400;
            x = "0.38 * safeZoneW + safeZoneX";
            y = "0.20 * safeZoneH + safeZoneY";
            w = "0.34 * safeZoneW";
            h = "0.035 * safeZoneH";
            onLBSelChanged = "[] call BO_fnc_logisticsRouteDialogPreview";
        };

        // Destination
        class LblDst: RscOverthrowStructuredText {
            idc = 1102;
            text = "<t>Destination</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.24 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class CmbDst: RscOverthrowCombo {
            idc = 1401;
            x = "0.38 * safeZoneW + safeZoneX";
            y = "0.24 * safeZoneH + safeZoneY";
            w = "0.34 * safeZoneW";
            h = "0.035 * safeZoneH";
            onLBSelChanged = "[] call BO_fnc_logisticsRouteDialogPreview";
        };

        // Items filter
        class LblItems: RscOverthrowStructuredText {
            idc = 1103;
            text = "<t>Items (blank = all)</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.29 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class EdtItems: RscOverthrowEdit {
            idc = 1402;
            text = "";
            x = "0.38 * safeZoneW + safeZoneX";
            y = "0.29 * safeZoneH + safeZoneY";
            w = "0.34 * safeZoneW";
            h = "0.035 * safeZoneH";
            tooltip = "Comma-separated classnames, e.g. OT_wood,OT_steel. Blank = move every item.";
        };

        // Quantity
        class LblQty: RscOverthrowStructuredText {
            idc = 1104;
            text = "<t>Qty per trip</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.335 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class EdtQty: RscOverthrowEdit {
            idc = 1403;
            text = "-1";
            x = "0.38 * safeZoneW + safeZoneX";
            y = "0.335 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.035 * safeZoneH";
            tooltip = "Maximum items per trip. -1 = move everything matching.";
        };

        // Schedule section
        class LblSched: RscOverthrowStructuredText {
            idc = 1105;
            text = "<t size='1.1'>Schedule</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.39 * safeZoneH + safeZoneY";
            w = "0.30 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class ModeManual: RscOverthrowButton {
            idc = 1620;
            action = "[0] call BO_fnc_logisticsRouteDialogSetMode";
            text = "Manual";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.425 * safeZoneH + safeZoneY";
            w = "0.14 * safeZoneW";
            h = "0.04 * safeZoneH";
            tooltip = "Manual only fires when you press Dispatch Now in the Routes tab.";
        };
        class ModeInterval: RscOverthrowButton {
            idc = 1621;
            action = "[1] call BO_fnc_logisticsRouteDialogSetMode";
            text = "Every N min";
            x = "0.415 * safeZoneW + safeZoneX";
            y = "0.425 * safeZoneH + safeZoneY";
            w = "0.14 * safeZoneW";
            h = "0.04 * safeZoneH";
            tooltip = "Fires every N in-game minutes since the last successful dispatch.";
        };
        class ModeTimeOfDay: RscOverthrowButton {
            idc = 1622;
            action = "[2] call BO_fnc_logisticsRouteDialogSetMode";
            text = "Time of day";
            x = "0.560 * safeZoneW + safeZoneX";
            y = "0.425 * safeZoneH + safeZoneY";
            w = "0.16 * safeZoneW";
            h = "0.04 * safeZoneH";
            tooltip = "Fires once per in-game day at the chosen HH:MM.";
        };

        // Interval inputs row
        class LblInterval: RscOverthrowStructuredText {
            idc = 1106;
            text = "<t>Every</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.05 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class EdtInterval: RscOverthrowEdit {
            idc = 1404;
            text = "30";
            x = "0.32 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.05 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class LblIntervalMin: RscOverthrowStructuredText {
            idc = 1107;
            text = "<t>min</t>";
            x = "0.375 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        // Presets
        class Pre15: RscOverthrowButton {
            idc = 1630;
            action = "ctrlSetText [1404, '15']";
            text = "15m";
            x = "0.42 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class Pre30: RscOverthrowButton {
            idc = 1631;
            action = "ctrlSetText [1404, '30']";
            text = "30m";
            x = "0.465 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class Pre60: RscOverthrowButton {
            idc = 1632;
            action = "ctrlSetText [1404, '60']";
            text = "1h";
            x = "0.510 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class Pre180: RscOverthrowButton {
            idc = 1633;
            action = "ctrlSetText [1404, '180']";
            text = "3h";
            x = "0.555 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class Pre360: RscOverthrowButton {
            idc = 1634;
            action = "ctrlSetText [1404, '360']";
            text = "6h";
            x = "0.600 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class Pre720: RscOverthrowButton {
            idc = 1635;
            action = "ctrlSetText [1404, '720']";
            text = "12h";
            x = "0.645 * safeZoneW + safeZoneX";
            y = "0.475 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // TimeOfDay inputs row
        class LblTime: RscOverthrowStructuredText {
            idc = 1108;
            text = "<t>At</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.520 * safeZoneH + safeZoneY";
            w = "0.05 * safeZoneW";
            h = "0.03 * safeZoneH";
        };
        class EdtHour: RscOverthrowEdit {
            idc = 1405;
            text = "12";
            x = "0.32 * safeZoneW + safeZoneX";
            y = "0.520 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
            tooltip = "Hour (0-23)";
        };
        class LblColon: RscOverthrowStructuredText {
            idc = 1109;
            text = "<t align='center' size='1.3'>:</t>";
            x = "0.36 * safeZoneW + safeZoneX";
            y = "0.520 * safeZoneH + safeZoneY";
            w = "0.02 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
        class EdtMinute: RscOverthrowEdit {
            idc = 1406;
            text = "00";
            x = "0.38 * safeZoneW + safeZoneX";
            y = "0.520 * safeZoneH + safeZoneY";
            w = "0.04 * safeZoneW";
            h = "0.035 * safeZoneH";
            tooltip = "Minute (0-59)";
        };

        // Skip-if-empty toggle
        class ToggleSkip: RscOverthrowButton {
            idc = 1623;
            action = "[] call BO_fnc_logisticsRouteDialogToggleSkip";
            text = "Skip if source empty: ON";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.575 * safeZoneH + safeZoneY";
            w = "0.34 * safeZoneW";
            h = "0.04 * safeZoneH";
            tooltip = "When the source has zero matching items, skip the trip silently rather than dispatching air.";
        };

        // Preview line (distance / travel time / fee)
        class Preview: RscOverthrowStructuredText {
            idc = 1110;
            text = "<t size='0.95' align='center' color='#bbbbbb'>Pick a source and destination to preview travel time and fee.</t>";
            x = "0.27 * safeZoneW + safeZoneX";
            y = "0.65 * safeZoneH + safeZoneY";
            w = "0.46 * safeZoneW";
            h = "0.045 * safeZoneH";
            colorBackground[] = {0, 0, 0, 0.3};
        };

        // Save / Cancel
        class Save: RscOverthrowButton {
            idc = 1640;
            action = "[] call BO_fnc_logisticsRouteDialogSubmit";
            text = "Save Route";
            x = "0.40 * safeZoneW + safeZoneX";
            y = "0.81 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
        class Cancel: RscOverthrowButton {
            idc = 1641;
            action = "closeDialog 0";
            text = "Cancel";
            x = "0.51 * safeZoneW + safeZoneX";
            y = "0.81 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.04 * safeZoneH";
        };
    };
};
