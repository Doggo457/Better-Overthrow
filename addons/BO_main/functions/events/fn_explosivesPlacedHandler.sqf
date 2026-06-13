private _unit = _this select 3;

if (side _unit isNotEqualTo independent || !(captive _unit)) exitWith {};
if (_unit call OT_fnc_unitSeen) then {
    _unit setCaptive false;
    "You have been seen placing an explosive" remoteExec ["OT_fnc_notifyMinor", owner _unit, false];
    // BO HAL hook: seen placing explosives is a heavy provocation --
    // and a doctrine lesson (the network learns you're a bomber).
    if (!isNil "BO_HAL_fnc_ingestSighting") then {
        [_unit, [], "explosives"] call BO_HAL_fnc_ingestSighting;
        ["ied"] remoteExec ["BO_HAL_fnc_doctrineNote", 2, false];
    };
    // if((random 100) > 70 && ((typeof _exp) select [0,3] == "IED")) then {
    //     [[_exp], -3] call ace_explosives_fnc_scriptedExplosive;
    // };
};
