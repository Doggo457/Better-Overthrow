private _aug = (_this select 0) getVariable ["OT_Attached", false];
if ((crew _aug) isNotEqualTo []) exitWith { hint 'Weapon must be empty to mount' };
(_this select 1) moveInGunner _aug;
