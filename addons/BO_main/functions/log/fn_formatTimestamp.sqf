#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_formatTimestamp
 *
 * Format the current in-game date as "YYYY-MM-DD HH:MM:SS" for log
 * and audit output. Pads fields to fixed width so log lines align
 * cleanly when read in a text editor.
 *
 * Params: none.
 *
 * Returns: STRING — formatted timestamp.
 */

private _d = date;
_d params ["_y", "_m", "_dd", "_hh", "_mm"];

private _pad = {
    params ["_n"];
    if (_n < 10) then { format ["0%1", _n] } else { str _n }
};

// Arma's date doesn't track seconds explicitly; use server tickTime
// as a stable secondary axis so two events in the same in-game minute
// can still be ordered.
private _sec = floor (serverTime mod 60);

format [
    "%1-%2-%3 %4:%5:%6",
    _y,
    [_m]  call _pad,
    [_dd] call _pad,
    [_hh] call _pad,
    [_mm] call _pad,
    [_sec] call _pad
];
