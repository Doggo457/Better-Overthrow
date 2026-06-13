private _amgen = (getPlayerUID player) in (server getVariable ["generals", []]);

createDialog 'OT_dialog_options';
if (!server_dedi) then {
    ctrlEnable [1608, false];
};
// BO: Toggle Zeus is now usable by Generals too -- they get the
// restricted curator, host/admin get the full one. fn_toggleZeus
// handles the routing.
if !(isServer || (call BIS_fnc_admin isEqualTo 2) || _amgen) then {
    ctrlEnable [1609, false];
    ctrlShow [1609, false];
};

if (!_amgen) then {
    ctrlEnable [1600, false];
    ctrlEnable [1607, false];
    ctrlEnable [1608, false];
    ctrlEnable [1601, false];
    ctrlEnable [1602, false];
    ctrlEnable [1603, false];
    ctrlEnable [1604, false];
};

// BO: HAL master toggle (IDC 1709, injected via build_extension.hpp).
// Same gate as Toggle Zeus -- host, logged-in admin, or General. Label
// reflects live state (BO_HAL_enabled is publicVariable'd by the
// server at init and on every toggle).
if !(isServer || (call BIS_fnc_admin isEqualTo 2) || _amgen) then {
    ctrlEnable [1709, false];
    ctrlShow [1709, false];
} else {
    ctrlSetText [1709, format ["HAL: %1", ["OFF", "ON"] select (missionNamespace getVariable ["BO_HAL_enabled", false])]];
};
