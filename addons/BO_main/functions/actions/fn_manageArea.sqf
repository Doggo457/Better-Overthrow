/*
 * fn_manageArea (BO override of OT_fnc_manageArea)
 *
 * Multi-factory: detection is no longer hardcoded to OT_factoryPos.
 * If the player is within 150m of any OT_factory-class object, we
 * open the factory dialog scoped to that specific factory by
 * setting OT_interactingWith to it. fn_factoryDialog then reads
 * that pin to decide which queue to display.
 *
 * Other manage flows (NATO objective, business) are unchanged.
 */

private _ob = player call OT_fnc_nearestObjective;
private _dist = (_ob select 0) distance player;
private _name = _ob select 1;

if (_dist < 250 && _name in (server getVariable ["NATOabandoned", []])) then {
    [] call OT_fnc_buyVehicleDialog;
} else {
    private _b = player call OT_fnc_nearestLocation;
    if ((_b select 1) isEqualTo "Business") then {
        [] call OT_fnc_buyBusiness;
    } else {
        // Multi-factory: find the nearest factory in 150m radius and
        // open scoped to that one. Falls back to OT_factoryPos
        // distance check only if no factory object is in range
        // (defensive for pre-init / no-factory states).
        private _nearestFactory = (getPosATL player) nearestObject OT_factory;
        private _nearFactoryDist = if (isNull _nearestFactory) then { 1e6 } else { player distance _nearestFactory };

        if (_nearFactoryDist < 150) then {
            if (call OT_fnc_playerIsGeneral) then {
                _name = "Factory";
                private _owned = server getVariable ["GEURowned", []];
                if (!(_name in _owned)) then {
                    [] call OT_fnc_buyBusiness;
                } else {
                    OT_interactingWith = _nearestFactory;
                    [] call OT_fnc_factoryDialog;
                };
            };
        };
    };
};
