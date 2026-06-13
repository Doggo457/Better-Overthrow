// Multi-factory: anchor the vehicle scan on the factory the player
// is interacting with (set by fn_factoryDialog), with a fallback to
// the nearest OT_factory within 150m. OT_factoryPos is frozen at the
// map-baked starter site and is NOT updated when players build new
// factories, so it cannot be used as the scan origin. Mirrors the
// resolution pattern in fn_factoryQueueAdd.
private _factory = OT_interactingWith;
if (isNull _factory || {(typeOf _factory) != OT_factory}) then {
    _factory = (getPosATL player) nearestObject OT_factory;
    if (!isNull _factory && {(player distance _factory) > 150}) then {
        _factory = objNull;
    };
};
private _anchor = if (isNull _factory) then { OT_factoryPos } else { getPosATL _factory };

createDialog 'OT_dialog_reverse';

private _playerstock = player call OT_fnc_unitStock;
private _cursel = lbCurSel 1500;
lbClear 1500;
private _numitems = 0;
private _blueprints = server getVariable ["GEURblueprints", []];
{
    _x params ["_cls"];
    if !((_cls in _blueprints) || (_cls in OT_allExplosives)) then {
        (_cls call OT_fnc_getClassDisplayInfo) params ["_pic", "_name"];

        private _idx = lbAdd [1500, _name];
        lbSetPicture [1500, _idx, _pic];
        lbSetData [1500, _idx, _cls];
        _numitems = _numitems + 1;
    };
} forEach (_playerstock);

{
    if (!(_x isKindOf "Animal") && !(_x isKindOf "CaManBase") && alive _x && (damage _x) isEqualTo 0) then {
        private _cls = typeOf _x;
        (_cls call OT_fnc_getClassDisplayInfo) params ["_pic", "_name"];

        private _idx = lbAdd [1500, _name];
        lbSetPicture [1500, _idx, _pic];
        lbSetData [1500, _idx, _cls];
        // Cache the exact vehicle's netId so the confirm step deletes
        // the right object instead of re-scanning around a stale pos.
        lbSetTooltip [1500, _idx, netId _x];
        _numitems = _numitems + 1;
    };
} forEach (_anchor nearObjects ["AllVehicles", 100]);

if (_cursel >= _numitems) then { _cursel = 0 };
lbSetCurSel [1500, _cursel];
