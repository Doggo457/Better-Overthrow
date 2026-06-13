#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_fireMissionPickCount
 *
 * Stage 2 of the fire-mission flow: round-count picker (1 / 3 / 6)
 * with computed per-round cost preview. Reads BO_fmShellType from
 * missionNamespace.
 *
 * Server re-derives the authoritative cost in BO_fnc_callFireMission;
 * the price shown here is a client-local preview only.
 */

private _shell = missionNamespace getVariable ["BO_fmShellType", ""];
if (_shell isEqualTo "") exitWith {};

// Locally-known per-round prices for the preview text.
private _prices = createHashMap;
_prices set ["HE",    500];
_prices set ["SMOKE", 150];
_prices set ["ILLUM", 100];
private _ppr = _prices getOrDefault [_shell, 500];

private _bank = call BO_fnc_getBankBalance;
private _bankFmt = [_bank, 1, 0, true] call CBA_fnc_formatNumber;

private _opts = [];
private _header = format ["<t align='center' size='1.1'>Rounds: %1</t><br/><t align='center' size='0.7'>Bank: $%2</t>",
    _shell, _bankFmt];
_opts pushBack _header;

{
    private _n = _x;
    private _costFmt = [_n * _ppr, 1, 0, true] call CBA_fnc_formatNumber;
    private _label = format ["%1 x %2 ($%3)", _n, _shell, _costFmt];
    _opts pushBack [
        _label,
        {
            missionNamespace setVariable ["BO_fmCount", _this select 0];
            [] call BO_fnc_fireMissionPickTarget;
        },
        [_n]
    ];
} forEach [1, 3, 6];

_opts pushBack ["Cancel", {}];
_opts call OT_fnc_playerDecision;
