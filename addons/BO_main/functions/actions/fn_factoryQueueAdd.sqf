/*
 * Client-side wrapper for the factory dialog "+1 / +10 / +100"
 * buttons. Resolves WHICH factory the player is managing from
 * OT_interactingWith (set by OT_fnc_manageArea when the dialog is
 * opened) with a fallback to the nearest OT_factory within 150m,
 * then routes the mutation through the server-auth target helper.
 *
 * Multi-factory: each factory has its own BO_queue var. The legacy
 * server-namespace factoryQueue / GEURproducing globals are no
 * longer authoritative; per-object state is.
 */

params ["_qty"];

private _idx = lbCurSel 1500;
if (_idx isEqualTo -1) exitWith {};

private _cls = lbData [1500, _idx];

// Resolve the target factory. Prefer the explicit OT_interactingWith
// (set by the manage flow). If that's null/dead (legacy callers, or
// the player opened the dialog directly), fall back to the closest
// factory class within 150m of the player.
private _factory = OT_interactingWith;
if (isNull _factory || {(typeOf _factory) != OT_factory}) then {
    _factory = (getPosATL player) nearestObject OT_factory;
    if (!isNull _factory && {(player distance _factory) > 150}) then {
        _factory = objNull;
    };
};
if (isNull _factory) exitWith {};

[_factory, _cls, _qty] remoteExec ["BO_fnc_factoryQueueAddTarget", 2, false];

[{ [] call OT_fnc_factoryRefresh; }, [], 0.1] call CBA_fnc_waitAndExecute;
