#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_loadoutTemplatesDialog
 *
 * Manage the player's custom recruit loadouts. Lists each unit class
 * they have an override for and offers Reset / Copy-from-another /
 * Cancel.
 *
 * NB: OT_fnc_playerDecision pops exactly ONE leading STRING as a
 * title, then expects every remaining element to be an [text, code,
 * args] tuple. Pushing additional bare strings (like a "(none)"
 * placeholder) crashes the iteration on `_x select 0` and leaves the
 * buttons showing their main.hpp default "Lorem ipsum..." text.
 * Use a disabled-style no-op tuple instead.
 */

private _ownTemplates = call BO_fnc_listPlayerTemplates;

private _opts = ["<t align='center' size='1.0'>Loadout Templates</t>"];

if (_ownTemplates isEqualTo []) then {
    _opts pushBack [
        "(no saved templates yet -- recruit a soldier, then Edit Loadout to start one)",
        {}
    ];
};

{
    private _cls = _x;
    private _displayName = _cls call OT_fnc_vehicleGetName;
    _opts pushBack [
        format ["Reset %1 to default", _displayName],
        { [_this] call BO_fnc_resetLoadoutToDefault },
        _cls
    ];
} forEach _ownTemplates;

_opts pushBack [
    "Copy a loadout from another player...",
    {
        private _otherOpts = ["<t align='center' size='0.9'>Copy from which player?</t>"];
        {
            if (_x isNotEqualTo player) then {
                _otherOpts pushBack [
                    name _x,
                    {
                        private _sourceUID = getPlayerUID _this;
                        private _classes = [_sourceUID] call BO_fnc_listPlayerTemplates;
                        if (_classes isEqualTo []) exitWith {
                            "That player has no custom loadouts to copy" call OT_fnc_notifyMinor;
                        };
                        private _classOpts = ["<t align='center' size='0.9'>Copy which loadout?</t>"];
                        {
                            _classOpts pushBack [
                                _x call OT_fnc_vehicleGetName,
                                { [_this select 0, _this select 1] call BO_fnc_copyLoadoutFromPlayer },
                                [_sourceUID, _x]
                            ];
                        } forEach _classes;
                        _classOpts pushBack ["Cancel", {}];
                        _classOpts call OT_fnc_playerDecision;
                    },
                    _x
                ];
            };
        } forEach allPlayers;
        if ((count _otherOpts) isEqualTo 1) then {
            _otherOpts pushBack ["(no other players online)", {}];
        };
        _otherOpts pushBack ["Cancel", {}];
        _otherOpts call OT_fnc_playerDecision;
    }
];

_opts pushBack ["Cancel", {}];
_opts call OT_fnc_playerDecision;
