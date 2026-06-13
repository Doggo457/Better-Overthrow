params ["_unit", "", "", "", "", ["_shooter", objNull], ["_projectile", objNull]];
_unit enableAI "PATH";
if !(isNull _projectile) then {
    private _shotParents = getShotParents _projectile;
    _shooter = _shotParents select 1;
};
if (isNull _shooter) then {
    private _aceSource = _unit getVariable ["ace_medical_lastDamageSource", objNull];
    if ((!isNull _aceSource) && { _aceSource != _unit }) then {
        _shooter = _aceSource;
    };
};
if ((typeOf _shooter) isKindOf "CAManBase") then {
    _shooter setCaptive false;
    if (!isNull objectParent _shooter) then {
        {
            _x setCaptive false;
        } forEach (crew objectParent _shooter);
    };
    // BO HAL hook: shooting NATO is the strongest sighting signal --
    // kit classification here drives the threat-matched response.
    if (!isNil "BO_HAL_fnc_ingestSighting") then {
        [_shooter, [], "damaged"] call BO_HAL_fnc_ingestSighting;
    };
};
