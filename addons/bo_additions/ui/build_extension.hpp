/*
 * build_extension.hpp -- bo_additions
 *
 * Adds BO buildable buttons to OT's three build dialogs (buildbase /
 * buildobjective / buildtown). Covers Factory, the six production
 * businesses (Lumberyard, Mine, Vineyard, Winery, Olive Plantation,
 * Chemical Plant) registered in OT_Buildables at fn_initVar.sqf:1082+,
 * and Mortar Position. Without these buttons the registry entries are
 * unreachable from the player-facing build flow (OT_fnc_build -> dialog
 * -> 'Name' call build), even though placement and init are wired.
 *
 * Pattern: bare-redeclare the dialog and its controls subclass --
 * NOT `class X: X` self-inheritance. The Arma engine merges classes
 * by name across PBOs at runtime: OT's config.bin contributes the
 * existing buttons, this file contributes the BO_* additions, both
 * end up in the merged class. This is the same pattern ACE3 uses for
 * extending BIS dialogs (cf. ACE3 addons/inventory/RscDisplayInventory.hpp).
 *
 * Only RscOverthrowButton needs a forward declaration -- it's the
 * parent of our new controls, defined in OT's config.bin. The dialog
 * classes themselves are not forward-declared (that would trip
 * hemtt's L-C03 duplicate-class check; bare redeclaration alone is
 * fine because the engine handles cross-PBO merge).
 *
 * Layout per dialog (OT's safeZone-relative grid uses ~0.088h row
 * spacing on a 0.077h button; left col x=0.0204687, right col
 * x=0.891875, plus a new middle col at x=0.456 for buildobjective
 * which is the most crowded dialog):
 *
 *   buildbase   -- left col 0.676 Factory, 0.764 Mortar Position
 *                  (defensive base context; civilian production sits
 *                  in objective/town dialogs).
 *   buildobjective -- right col 0.764 Factory; middle col 0.324..0.764
 *                     fits the six businesses; left col 0.852 Mortar
 *                     (objectives = captured NATO sites, the most
 *                     general-purpose context).
 *   buildtown   -- left col 0.764 Factory; right col 0.324..0.676 +
 *                  0.852 fits the six businesses (towns are the
 *                  natural civilian-production home).
 *
 * IDC convention: 1700+ is BO-reserved (see Options menu BO_AuditLog
 * at 1701). IDCs are per-dialog scoped by the engine, so reusing the
 * same number across different dialogs is safe and keeps the mapping
 * Factory=1700, Mortar=1702, Lumberyard=1703, Mine=1704,
 * Vineyard=1705, Winery=1706, Olive Plantation=1707, Chemical Plant=1708
 * consistent everywhere.
 */

class RscOverthrowButton;

class OT_dialog_buildbase {
    class controls {
        class BO_Factory: RscOverthrowButton {
            idc = 1700;
            action = "'Factory' call build";
            text = "Factory";
            x = "0.0204687 * safeZoneW + safeZoneX";
            y = "0.676 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production facility -- $20,000. Activates as the new factory site on placement.";
        };
        class BO_Mortar: RscOverthrowButton {
            idc = 1702;
            action = "'Mortar Position' call build";
            text = "Mortar Position";
            x = "0.0204687 * safeZoneW + safeZoneX";
            y = "0.764 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Buildable mortar -- $3,500. Enables 'Call Fire Mission' ACE action. Pay per round from your bank: HE $500, Smoke $150, Illum $100. 5 min cooldown.";
        };
    };
};

class OT_dialog_buildobjective {
    class controls {
        class BO_Factory: RscOverthrowButton {
            idc = 1700;
            action = "'Factory' call build";
            text = "Factory";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.764 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production facility -- $20,000. Activates as the new factory site on placement.";
        };
        class BO_Lumberyard: RscOverthrowButton {
            idc = 1703;
            action = "'Lumberyard' call build";
            text = "Lumberyard";
            x = "0.456 * safeZoneW + safeZoneX";
            y = "0.324 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $1,500. Produces ~10 Wood/hr, employs 5. No input required.";
        };
        class BO_Mine: RscOverthrowButton {
            idc = 1704;
            action = "'Mine' call build";
            text = "Mine";
            x = "0.456 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $5,000. Produces ~8 Steel/hr, employs 6. No input required.";
        };
        class BO_Vineyard: RscOverthrowButton {
            idc = 1705;
            action = "'Vineyard' call build";
            text = "Vineyard";
            x = "0.456 * safeZoneW + safeZoneX";
            y = "0.5 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $2,500. Grows ~12 Grapes/hr, employs 4. No input required.";
        };
        class BO_Winery: RscOverthrowButton {
            idc = 1706;
            action = "'Winery' call build";
            text = "Winery";
            x = "0.456 * safeZoneW + safeZoneX";
            y = "0.588 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $5,000. Processes Grapes into ~8 Wine/hr, employs 6. Requires 8 grapes/hr in the adjacent I/O crate.";
        };
        class BO_OlivePlantation: RscOverthrowButton {
            idc = 1707;
            action = "'Olive Plantation' call build";
            text = "Olive Plantation";
            x = "0.456 * safeZoneW + safeZoneX";
            y = "0.676 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $2,500. Produces ~12 Olives/hr, employs 4. No input required.";
        };
        class BO_ChemicalPlant: RscOverthrowButton {
            idc = 1708;
            action = "'Chemical Plant' call build";
            text = "Chemical Plant";
            x = "0.456 * safeZoneW + safeZoneX";
            y = "0.764 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $8,000. Produces ~6 Fertilizer/hr, employs 8. No input required.";
        };
        class BO_Mortar: RscOverthrowButton {
            idc = 1702;
            action = "'Mortar Position' call build";
            text = "Mortar Position";
            x = "0.0204687 * safeZoneW + safeZoneX";
            y = "0.852 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Buildable mortar -- $3,500. Enables 'Call Fire Mission' ACE action. Pay per round from your bank: HE $500, Smoke $150, Illum $100. 5 min cooldown.";
        };
    };
};

class OT_dialog_buildtown {
    class controls {
        class BO_Factory: RscOverthrowButton {
            idc = 1700;
            action = "'Factory' call build";
            text = "Factory";
            x = "0.0204687 * safeZoneW + safeZoneX";
            y = "0.764 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production facility -- $20,000. Activates as the new factory site on placement.";
        };
        class BO_Lumberyard: RscOverthrowButton {
            idc = 1703;
            action = "'Lumberyard' call build";
            text = "Lumberyard";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.324 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $1,500. Produces ~10 Wood/hr, employs 5. No input required.";
        };
        class BO_Mine: RscOverthrowButton {
            idc = 1704;
            action = "'Mine' call build";
            text = "Mine";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.412 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $5,000. Produces ~8 Steel/hr, employs 6. No input required.";
        };
        class BO_Vineyard: RscOverthrowButton {
            idc = 1705;
            action = "'Vineyard' call build";
            text = "Vineyard";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.5 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $2,500. Grows ~12 Grapes/hr, employs 4. No input required.";
        };
        class BO_Winery: RscOverthrowButton {
            idc = 1706;
            action = "'Winery' call build";
            text = "Winery";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.588 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $5,000. Processes Grapes into ~8 Wine/hr, employs 6. Requires 8 grapes/hr in the adjacent I/O crate.";
        };
        class BO_OlivePlantation: RscOverthrowButton {
            idc = 1707;
            action = "'Olive Plantation' call build";
            text = "Olive Plantation";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.676 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $2,500. Produces ~12 Olives/hr, employs 4. No input required.";
        };
        class BO_ChemicalPlant: RscOverthrowButton {
            idc = 1708;
            action = "'Chemical Plant' call build";
            text = "Chemical Plant";
            x = "0.891875 * safeZoneW + safeZoneX";
            y = "0.852 * safeZoneH + safeZoneY";
            w = "0.0876563 * safeZoneW";
            h = "0.077 * safeZoneH";
            tooltip = "Production business -- $8,000. Produces ~6 Fertilizer/hr, employs 8. No input required.";
        };
    };
};

// Audit Log button added to the Options menu (Esc -> Options). Moved
// out of the Y menu where it was colliding with Recon Flights on the
// y=0.863/0.864 row. Audit is a meta/admin tool so the Options panel
// fits its role; the Y menu stays focused on in-game actions.
//
// Slot: y=0.797 (next row below Toggle Zeus at 0.709, matching its
// wide w=0.2475 layout). IDC 1701 -- next free after BO_Factory's 1700.
class OT_dialog_options {
    class controls {
        class BO_AuditLog: RscOverthrowButton {
            idc = 1701;
            action = "closeDialog 0; [] spawn BO_fnc_auditViewerDialog;";
            text = "Audit Log";
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.797 * safeZoneH + safeZoneY";
            w = "0.2475 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Recent audited events: ATM transactions, factory placements, pricing fallbacks, garage/insurance/recon/artillery/civilian/events actions.";
        };
        // HAL master toggle -- own full-width row below Audit Log
        // (the 0.709 row turned out to be a full-width Toggle Zeus;
        // sharing it overlapped). Host/admin/General only: text +
        // gating applied at open time by BO_fnc_optionsDialog
        // (IDC 1709). Flips the live strategic AI on the server;
        // state persists with the save (BO_HAL_enabledOverride).
        class BO_HALToggle: RscOverthrowButton {
            idc = 1709;
            action = "[!(missionNamespace getVariable ['BO_HAL_enabled', false]), getPlayerUID player, name player] remoteExec ['BO_HAL_fnc_setEnabled', 2, false]; closeDialog 0;";
            text = "HAL";
            x = "0.386562 * safeZoneW + safeZoneX";
            y = "0.852 * safeZoneH + safeZoneY";
            w = "0.2475 * safeZoneW";
            h = "0.044 * safeZoneH";
            tooltip = "Toggle the NATO HAL strategic AI (threat-matched responses, recon probes, garrison convoys, interdiction). State saves with the campaign.";
        };
    };
};
