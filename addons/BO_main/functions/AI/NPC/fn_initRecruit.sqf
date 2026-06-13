params ["_civ"];

removeAllActions _civ;
_civ removeAllEventHandlers "FiredNear";

[_civ, selectRandom OT_voices_local] remoteExecCall ["setSpeaker", 0, _civ];

_civ setSkill 0.1 + (random 0.3);
_civ setRank "PRIVATE";
_civ setVariable ["NOAI", true, true];

_civ call OT_fnc_wantedSystem;

private _nameparts = [name _civ];
_nameparts append (name _civ splitString " ");

// MP race: route through server-only adjuster instead of client RMW of server "recruits"
[[getPlayerUID player, _nameparts, _civ, "PRIVATE", [], typeOf _civ]] remoteExec ["BO_fnc_addRecruit", 2, false];
