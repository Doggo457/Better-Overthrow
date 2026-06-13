/*
 * garage.hpp -- bo_additions
 *
 *   BO_dialog_garage (IDD 8052) -- two-tab persistent garage UI:
 *     Stored | Nearby. Lists are populated from SQF; button clicks
 *     route to BO_fnc_garageStore / garageRetrieve / garageInsure /
 *     garageCancelInsurance via remoteExec.
 *
 * Pattern: bare class redeclaration (no `class X: X`), same as
 * logistics.hpp / build_extension.hpp. RscOverthrow* bases are
 * forward-declared in build_extension.hpp which is #included earlier;
 * we forward-declare the ones we use here that aren't already
 * declared by logistics.hpp.
 *
 * IDC map:
 *   1100 - title text
 *   1101 - summary text (slot count / list count)
 *   1199 - dark background panel
 *   1500 - listbox (stored items in Stored tab, vehicles in Nearby tab)
 *   1600 - Close
 *   1610 - Store          (Nearby tab selection -> BO_fnc_garageStore)
 *   1611 - Retrieve       (Stored tab selection -> BO_fnc_garageRetrieve)
 *   1612 - Insure         (Nearby tab selection -> BO_fnc_garageInsure)
 *   1613 - Cancel Ins.    (Nearby tab selection -> BO_fnc_garageCancelInsurance)
 *   1620 - Stored tab
 *   1621 - Nearby tab
 */

// RscOverthrowStructuredText / ListBox / Button are already forward-
// declared by build_extension.hpp / logistics.hpp (both #included
// earlier from config.cpp). Re-declaring here would trip hemtt L-C03.

class BO_dialog_garage {
    idd = 8052;
    movingenable = 0;
    onLoad = "uiNamespace setVariable ['BO_dialog_garage', _this select 0]";
    onUnload = "uiNamespace setVariable ['BO_dialog_garage', displayNull]";

    class controlsBackground {
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
        class Title: RscOverthrowStructuredText {
            idc = 1100;
            text = "<t size='1.5' align='center'>GARAGE</t>";
            x = "0.18 * safeZoneW + safeZoneX";
            y = "0.12 * safeZoneH + safeZoneY";
            w = "0.64 * safeZoneW";
            h = "0.04 * safeZoneH";
        };

        class Summary: RscOverthrowStructuredText {
            idc = 1101;
            text = "";
            x = "0.40 * safeZoneW + safeZoneX";
            y = "0.18 * safeZoneH + safeZoneY";
            w = "0.40 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        class CloseBtn: RscOverthrowButton {
            idc = 1600;
            text = "Close";
            action = "closeDialog 0";
            x = "0.74 * safeZoneW + safeZoneX";
            y = "0.12 * safeZoneH + safeZoneY";
            w = "0.07 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        class TabStored: RscOverthrowButton {
            idc = 1620;
            text = "Stored";
            action = "[(uiNamespace getVariable ['BO_dialog_garage', displayNull]), 'stored'] call (uiNamespace getVariable 'BO_garageDialog_populate')";
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.18 * safeZoneH + safeZoneY";
            w = "0.09 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        class TabNearby: RscOverthrowButton {
            idc = 1621;
            text = "Nearby";
            action = "[(uiNamespace getVariable ['BO_dialog_garage', displayNull]), 'nearby'] call (uiNamespace getVariable 'BO_garageDialog_populate')";
            x = "0.295 * safeZoneW + safeZoneX";
            y = "0.18 * safeZoneH + safeZoneY";
            w = "0.09 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        class List: RscOverthrowListBox {
            idc = 1500;
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.225 * safeZoneH + safeZoneY";
            w = "0.60 * safeZoneW";
            h = "0.55 * safeZoneH";
            sizeEx = 0.03;
        };

        // Store: Nearby selection (lbData = netId) -> server fn.
        class StoreBtn: RscOverthrowButton {
            idc = 1610;
            text = "Store";
            action = "call { private _i = lbCurSel 1500; if (_i < 0) exitWith { 'Select a nearby vehicle first' call OT_fnc_notifyMinor }; private _nid = lbData [1500, _i]; private _veh = objectFromNetId _nid; if (isNull _veh) exitWith {}; private _wh = uiNamespace getVariable ['BO_dialog_garage_warehouse', objNull]; closeDialog 0; [_veh, getPlayerUID player, name player, _wh] remoteExec ['BO_fnc_garageStore', 2, false]; }";
            x = "0.20 * safeZoneW + safeZoneX";
            y = "0.79 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // Retrieve: Stored selection (lbData = garageId) -> server fn.
        class RetrieveBtn: RscOverthrowButton {
            idc = 1611;
            text = "Retrieve";
            action = "call { private _i = lbCurSel 1500; if (_i < 0) exitWith { 'Select a stored vehicle first' call OT_fnc_notifyMinor }; private _id = lbData [1500, _i]; private _wh = uiNamespace getVariable ['BO_dialog_garage_warehouse', objNull]; closeDialog 0; [_id, _wh, getPlayerUID player, name player] remoteExec ['BO_fnc_garageRetrieve', 2, false]; }";
            x = "0.305 * safeZoneW + safeZoneX";
            y = "0.79 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // Insure: Nearby selection -> server fn.
        class InsureBtn: RscOverthrowButton {
            idc = 1612;
            text = "Insure";
            action = "call { private _i = lbCurSel 1500; if (_i < 0) exitWith { 'Select a nearby vehicle first' call OT_fnc_notifyMinor }; private _nid = lbData [1500, _i]; private _veh = objectFromNetId _nid; if (isNull _veh) exitWith {}; closeDialog 0; [_veh, getPlayerUID player, name player] remoteExec ['BO_fnc_garageInsure', 2, false]; }";
            x = "0.41 * safeZoneW + safeZoneX";
            y = "0.79 * safeZoneH + safeZoneY";
            w = "0.10 * safeZoneW";
            h = "0.035 * safeZoneH";
        };

        // Cancel Insurance: Nearby selection -> server fn.
        class CancelInsBtn: RscOverthrowButton {
            idc = 1613;
            text = "Cancel Insurance";
            action = "call { private _i = lbCurSel 1500; if (_i < 0) exitWith { 'Select a nearby vehicle first' call OT_fnc_notifyMinor }; private _nid = lbData [1500, _i]; private _veh = objectFromNetId _nid; if (isNull _veh) exitWith {}; closeDialog 0; [_veh, getPlayerUID player, name player] remoteExec ['BO_fnc_garageCancelInsurance', 2, false]; }";
            x = "0.515 * safeZoneW + safeZoneX";
            y = "0.79 * safeZoneH + safeZoneY";
            w = "0.13 * safeZoneW";
            h = "0.035 * safeZoneH";
        };
    };
};
