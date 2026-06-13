if (isDedicated) exitWith {};
params ["_new", "_old"];

if (isNull (_old)) exitWith {};

//remove last body from spawn distance check
{
    if ((_x isNotEqualTo _old) && (getPlayerUID player) isEqualTo (_x getVariable ["player_uid", false])) then {
        _x setVariable ["player_uid", false, true];
    };
} forEach (allDeadMen);

titleText ["", "BLACK FADED", 0];

waitUntil { alive player };
player setCaptive true;
player allowDamage false;

private _group = createGroup independent;
[player] joinSilent nil;
[player] joinSilent _group;
private _recruits = server getVariable ["recruits", []];
{
    _x params ["_owner", "", "_civ"];
    if (_owner isEqualTo (getPlayerUID player)) then {
        if (_civ isEqualType objNull) then {
            if (_civ call OT_fnc_playerIsOwner) then {
                [_civ] joinSilent (group player);
                commandStop _civ;
            };
        };
    };
} forEach (_recruits);

private _money = player getVariable ["money", 0];
private _take = floor (_money * 0.05);
if (_take > 0) then {
    [-_take] call OT_fnc_money;
};

removeHeadgear player;
removeAllWeapons player;
removeAllAssignedItems player;
removeGoggles player;
removeBackpack player;
removeVest player;

player setVariable ["ot_isSmoking", false];
player addWeaponGlobal "ItemMap";

private _housepos = _old getVariable "home";
player setPos (_housepos findEmptyPosition [1, 20, typeOf _new]);
private _clothes = uniform _old;
player forceAddUniform _clothes;
[] spawn OT_fnc_setupPlayer;

call {
    disableSerialization;
    private _display = uiNamespace getVariable "OT_statsHUD";
    if (isNil "_display") exitWith {};
    private _setText = _display displayCtrl 1001;
    _setText ctrlSetStructuredText (parseText "");
    _setText ctrlCommit 0;
};

titleText ["", "BLACK IN", 5];

[] spawn {
    sleep 5;
    player allowDamage true;
};
