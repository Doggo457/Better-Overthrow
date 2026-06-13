#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_auditViewerDialog
 *
 * Open a scrollable audit-log viewer. Hijacks OT_dialog_jobs (idd=8000)
 * as the container -- it already has the right shape: a scrollable
 * RscOverthrowListBox on the left (IDC 1500), a structured-text
 * details panel on the right (IDC 1100), and a built-in X close button
 * (IDC 1699). The waypoint buttons (1600/1601) and the picture (1200)
 * are hidden because they don't apply to an audit log.
 *
 * The OT-defined LBSelChanged handler points at OT_fnc_displayJobDetails;
 * we override it at runtime to show audit details instead.
 *
 * Pulls the last hour, up to 500 entries, newest-first (the cap is
 * generous because the listbox is scrollable).
 *
 * BO additions (this revision):
 *   - Category dropdown (IDC 1701) filters visible entries by bucket.
 *   - Actor dropdown    (IDC 1702) filters visible entries by actor.
 *   - Export button     (IDC 1703) copies the currently-filtered
 *                                  view to the clipboard as plain text.
 *
 * The new controls are runtime-injected via ctrlCreate -- OT_dialog_jobs
 * is shipped in a precompiled config so we can't add controls via .hpp.
 * The hijack pattern matches BO_fnc_mainMenu's Y-menu injections.
 *
 * Data shape: each entry from BO_fnc_auditServer is a 6-tuple
 *   [date, tickTime, actorUID, actorName, description, details]
 * with no category embedded. To support category filtering we pull each
 * bucket separately via BO_fnc_exportAudit and build a parallel
 * BO_auditViewerCategories array of the same length as the entries
 * array; index N in entries corresponds to index N in categories.
 */

// Categories must match the buckets pre-seeded in BO_fnc_initAuditLog.
private _allCategories = ["atm", "mission", "save", "admin", "pricing", "garbage", "logistics", "civilian", "intel", "events"];

// Pull per category so we can tag each entry with its bucket. We can't
// rely on a single combined call because exportAudit's tuple shape is
// [date, tick, uid, name, desc, details] -- no category field. Each
// per-bucket query honours the same 3600-fractional-year age window
// (effectively unbounded) and a generous per-bucket cap; we then merge
// + sort + trim to the global 500 cap that the listbox is shaped for.
private _entriesPool = [];
private _categoryPool = [];
{
    private _cat = _x;
    private _bucket = [[_cat], "", 3600, 500] call BO_fnc_exportAudit;
    {
        _entriesPool pushBack _x;
        _categoryPool pushBack _cat;
    } forEach _bucket;
} forEach _allCategories;

if (_entriesPool isEqualTo []) exitWith {
    "No recent audit entries" call OT_fnc_notifyMinor;
};

// Merge sort newest-first (each per-bucket call is already sorted, but
// the concatenation isn't globally ordered). Use a paired sort by
// dateToNumber so the parallel categories array stays aligned.
private _paired = [];
{
    _paired pushBack [_x, _categoryPool select _forEachIndex];
} forEach _entriesPool;

private _sortedPaired = [_paired, [], { dateToNumber ((_x select 0) select 0) }, "DESCEND"] call BIS_fnc_sortBy;

// Trim to 500 globally to match the previous listbox shape.
if (count _sortedPaired > 500) then {
    _sortedPaired resize 500;
};

_entriesPool = _sortedPaired apply { _x select 0 };
_categoryPool = _sortedPaired apply { _x select 1 };

closeDialog 0;
createDialog "OT_dialog_jobs";
disableSerialization;

private _disp = findDisplay 8000;
if (isNull _disp) exitWith {
    "Audit viewer could not open" call OT_fnc_notifyMinor;
};

// Hide controls that don't apply to audit viewing.
ctrlShow [1200, false]; // picture
ctrlShow [1600, false]; // Set Waypoint
ctrlShow [1601, false]; // Clear Waypoint

// Stash the (sorted, capped) pool on the display so the engine clears
// it on Unload; the previous missionNamespace stash leaked until the
// next open. The category pool stays parallel-indexed with entries.
_disp setVariable ["BO_auditViewerEntries", _entriesPool];
_disp setVariable ["BO_auditViewerCategories", _categoryPool];

// =========================================================================
// Filter row: [Category v]  [Actor v]  [Export to Clipboard]
//
// OT_dialog_jobs lays its listbox out at y=0.225 h=0.55 inside a
// 0.214..0.786 background panel. We shrink the listbox top by ~0.045
// safeZoneH to fit a single row of filters above it. The X close button
// at y=0.181 stays clear because the filter row starts at y=0.228.
//
// IDC range: 17xx is unused by OT_dialog_jobs (1100, 1199, 1200, 1500,
// 1600, 1601, 1699). 17xx also doesn't collide with the runtime-injected
// IDCs BO_fnc_mainMenu uses on the *other* dialog (idd=8001).
// =========================================================================

private _lb = _disp displayCtrl 1500;

// Shrink the listbox top to leave room for the filter row.
private _lbX = 0.247344 * safeZoneW + safeZoneX;
private _lbY = 0.272   * safeZoneH + safeZoneY;
private _lbW = 0.402187 * safeZoneW;
private _lbH = 0.503   * safeZoneH;
_lb ctrlSetPosition [_lbX, _lbY, _lbW, _lbH];
_lb ctrlCommit 0;

// Label: "Category"
private _lblCat = _disp ctrlCreate ["RscOverthrowStructuredText", 1711];
_lblCat ctrlSetPosition [
    0.247344 * safeZoneW + safeZoneX,
    0.223   * safeZoneH + safeZoneY,
    0.060   * safeZoneW,
    0.033   * safeZoneH
];
_lblCat ctrlSetStructuredText parseText "<t size='0.8' align='left'>Category</t>";
_lblCat ctrlCommit 0;

// Combo: Category filter
private _cmbCat = _disp ctrlCreate ["RscOverthrowCombo", 1701];
_cmbCat ctrlSetPosition [
    0.310   * safeZoneW + safeZoneX,
    0.228   * safeZoneH + safeZoneY,
    0.105   * safeZoneW,
    0.033   * safeZoneH
];
_cmbCat ctrlCommit 0;

// Label: "Actor"
private _lblAct = _disp ctrlCreate ["RscOverthrowStructuredText", 1712];
_lblAct ctrlSetPosition [
    0.420   * safeZoneW + safeZoneX,
    0.223   * safeZoneH + safeZoneY,
    0.045   * safeZoneW,
    0.033   * safeZoneH
];
_lblAct ctrlSetStructuredText parseText "<t size='0.8' align='left'>Actor</t>";
_lblAct ctrlCommit 0;

// Combo: Actor filter
private _cmbAct = _disp ctrlCreate ["RscOverthrowCombo", 1702];
_cmbAct ctrlSetPosition [
    0.467   * safeZoneW + safeZoneX,
    0.228   * safeZoneH + safeZoneY,
    0.105   * safeZoneW,
    0.033   * safeZoneH
];
_cmbAct ctrlCommit 0;

// Button: Export to Clipboard
private _btnExp = _disp ctrlCreate ["RscOverthrowButton", 1703];
_btnExp ctrlSetText "Export to Clipboard";
_btnExp ctrlSetTooltip "Copy the currently-filtered audit entries to the clipboard as plain text";
_btnExp ctrlSetPosition [
    0.577   * safeZoneW + safeZoneX,
    0.228   * safeZoneH + safeZoneY,
    0.072   * safeZoneW,
    0.033   * safeZoneH
];
_btnExp ctrlCommit 0;

// Populate Category combo: "All" + the categories that actually have
// entries in the snapshot. lbData holds the raw category key (or ""
// for All) so the filter handler can compare against _categoryPool.
{
    lbClear _x;
} forEach [_cmbCat, _cmbAct];

private _allIdx = _cmbCat lbAdd "All categories";
_cmbCat lbSetData [_allIdx, ""];
private _presentCats = [];
{
    if !(_x in _presentCats) then { _presentCats pushBack _x };
} forEach _categoryPool;
{
    private _idx = _cmbCat lbAdd _x;
    _cmbCat lbSetData [_idx, _x];
} forEach _presentCats;
_cmbCat lbSetCurSel 0;

// Populate Actor combo: "All" + distinct actor names from the pool.
// Empty names (server-initiated entries) collapse to the literal
// label "server"; lbData stores the raw value ("" for server) so
// the filter can compare directly against _actorName.
private _allActIdx = _cmbAct lbAdd "All actors";
_cmbAct lbSetData [_allActIdx, "__ALL__"];

private _presentActors = [];
{
    private _name = _x select 3;
    if (!(_name isEqualType "")) then { _name = "" };
    if !(_name in _presentActors) then { _presentActors pushBack _name };
} forEach _entriesPool;

{
    private _label = [_x, "server"] select (_x isEqualTo "");
    private _idx = _cmbAct lbAdd _label;
    _cmbAct lbSetData [_idx, _x];
} forEach _presentActors;
_cmbAct lbSetCurSel 0;

// =========================================================================
// Renderer: walks the pool, applies current combo selections, fills lb.
// Stored on display under BO_auditViewerRender so combo handlers + the
// export button can re-invoke it. Each row's lbData is `str <poolIdx>`
// so the LBSelChanged handler still looks up against the full pool.
// =========================================================================
_disp setVariable ["BO_auditViewerRender", {
    params ["_disp"];
    private _entries  = _disp getVariable ["BO_auditViewerEntries", []];
    private _cats     = _disp getVariable ["BO_auditViewerCategories", []];
    private _cmbCat   = _disp displayCtrl 1701;
    private _cmbAct   = _disp displayCtrl 1702;
    private _lb       = _disp displayCtrl 1500;

    private _catSel = _cmbCat lbData (lbCurSel _cmbCat);
    private _actSel = _cmbAct lbData (lbCurSel _cmbAct);
    // "" on the category combo means All; "__ALL__" sentinel on the
    // actor combo means All (we couldn't reuse "" there because empty
    // is a legitimate value meaning server-initiated).
    private _filterCat   = _catSel isNotEqualTo "";
    private _filterActor = _actSel isNotEqualTo "__ALL__";

    lbClear _lb;
    {
        private _entry = _x;
        private _entryCat = _cats param [_forEachIndex, ""];
        private _name = _entry param [3, ""];
        if (!(_name isEqualType "")) then { _name = "" };

        private _passes = true;
        if (_filterCat   && {_entryCat isNotEqualTo _catSel}) then { _passes = false };
        if (_passes && _filterActor && {_name isNotEqualTo _actSel}) then { _passes = false };

        if (_passes) then {
            private _date = _entry select 0;
            private _desc = _entry param [4, ""];
            private _hh = if (count _date >= 4) then { _date select 3 } else { 0 };
            private _mm = if (count _date >= 5) then { _date select 4 } else { 0 };
            private _hhStr = if (_hh < 10) then { format ["0%1", _hh] } else { str _hh };
            private _mmStr = if (_mm < 10) then { format ["0%1", _mm] } else { str _mm };
            private _who = ["server", _name] select (_name isNotEqualTo "");
            private _row = format ["[%1:%2] {%3} (%4) %5", _hhStr, _mmStr, _entryCat, _who, _desc];
            private _rowIdx = _lb lbAdd _row;
            _lb lbSetData [_rowIdx, str _forEachIndex];
        };
    } forEach _entries;
}];

// Wire combos to re-render. Skip the synthetic LBSelChanged the engine
// fires while we're populating (lbAdd inside populate would otherwise
// recurse). Both combos call the same renderer.
_cmbCat ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl"];
    private _disp = ctrlParent _ctrl;
    private _render = _disp getVariable ["BO_auditViewerRender", {}];
    [_disp] call _render;
}];
_cmbAct ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl"];
    private _disp = ctrlParent _ctrl;
    private _render = _disp getVariable ["BO_auditViewerRender", {}];
    [_disp] call _render;
}];

// Wire export button. Walks the currently-filtered entries (re-applying
// the same predicate the renderer uses), formats each as a one-line
// plain-text record, joins with newlines, hands off to copyToClipboard.
_btnExp ctrlAddEventHandler ["ButtonClick", {
    params ["_ctrl"];
    private _disp = ctrlParent _ctrl;
    private _entries = _disp getVariable ["BO_auditViewerEntries", []];
    private _cats    = _disp getVariable ["BO_auditViewerCategories", []];
    private _cmbCat  = _disp displayCtrl 1701;
    private _cmbAct  = _disp displayCtrl 1702;

    private _catSel = _cmbCat lbData (lbCurSel _cmbCat);
    private _actSel = _cmbAct lbData (lbCurSel _cmbAct);
    private _filterCat   = _catSel isNotEqualTo "";
    private _filterActor = _actSel isNotEqualTo "__ALL__";

    private _lines = [];
    {
        private _entry = _x;
        private _entryCat = _cats param [_forEachIndex, ""];
        private _name = _entry param [3, ""];
        if (!(_name isEqualType "")) then { _name = "" };

        private _passes = true;
        if (_filterCat   && {_entryCat isNotEqualTo _catSel}) then { _passes = false };
        if (_passes && _filterActor && {_name isNotEqualTo _actSel}) then { _passes = false };

        if (_passes) then {
            private _date = _entry select 0;
            private _desc = _entry param [4, ""];
            private _details = _entry param [5, ""];
            private _yy = _date param [0, 0];
            private _mo = _date param [1, 0];
            private _dd = _date param [2, 0];
            private _hh = _date param [3, 0];
            private _mm = _date param [4, 0];
            private _ss = _date param [5, 0];
            private _moStr = if (_mo < 10) then { format ["0%1", _mo] } else { str _mo };
            private _ddStr = if (_dd < 10) then { format ["0%1", _dd] } else { str _dd };
            private _hhStr = if (_hh < 10) then { format ["0%1", _hh] } else { str _hh };
            private _mmStr = if (_mm < 10) then { format ["0%1", _mm] } else { str _mm };
            private _ssStr = if (_ss < 10) then { format ["0%1", _ss] } else { str _ss };
            private _who = ["server", _name] select (_name isNotEqualTo "");
            _lines pushBack format [
                "[%1-%2-%3 %4:%5:%6] [%7] [%8] %9 (%10)",
                _yy, _moStr, _ddStr, _hhStr, _mmStr, _ssStr,
                _entryCat, _who, _desc, str _details
            ];
        };
    } forEach _entries;

    if (_lines isEqualTo []) exitWith {
        "No entries match the current filter" call OT_fnc_notifyMinor;
    };

    copyToClipboard (_lines joinString endl);
    format ["Exported %1 entries to clipboard", count _lines] call OT_fnc_notifyMinor;
}];

// Replace the OT-config handler ("call OT_fnc_displayJobDetails") with
// an inline audit-detail handler. The new handler reads the row data,
// looks up the entry by index, and writes a formatted breakdown into
// the right-side text panel (IDC 1100). Index is into the *full* pool
// stashed on the display, not into the visible filtered list, so the
// row's lbData stays valid across filter changes.
_lb ctrlSetEventHandler ["LBSelChanged", "
    params ['_ctrl', '_idx'];
    private _disp = ctrlParent _ctrl;
    private _entries = _disp getVariable ['BO_auditViewerEntries', []];
    private _cats    = _disp getVariable ['BO_auditViewerCategories', []];
    private _key = _ctrl lbData _idx;
    // Guard empty lbData (no row selected / stale event): parseNumber ''
    // resolves to 0 and would otherwise display entry 0.
    if (_key isEqualTo '') exitWith {};
    private _entryIdx = parseNumber _key;
    if (_entryIdx < 0 || _entryIdx >= count _entries) exitWith {};
    private _entry = _entries select _entryIdx;
    private _entryCat = _cats param [_entryIdx, ''];
    _entry params ['_date', '_tick', '_actorUID', '_actorName', '_desc'];
    private _details = _entry param [5, ''];

    private _yy = _date select 0;
    private _mo = _date select 1;
    private _dd = _date select 2;
    private _hh = _date select 3;
    private _mm = _date select 4;
    private _ss = _date param [5, 0];
    private _moStr = if (_mo < 10) then { format ['0%1', _mo] } else { str _mo };
    private _ddStr = if (_dd < 10) then { format ['0%1', _dd] } else { str _dd };
    private _hhStr = if (_hh < 10) then { format ['0%1', _hh] } else { str _hh };
    private _mmStr = if (_mm < 10) then { format ['0%1', _mm] } else { str _mm };
    private _ssStr = if (_ss < 10) then { format ['0%1', _ss] } else { str _ss };
    private _who = if (_actorName isEqualType '' && {_actorName isNotEqualTo ''}) then {
        format ['%1 (%2)', _actorName, _actorUID]
    } else { 'server' };

    private _text = format [
        '<t size=''0.75'' align=''left'' color=''#dddddd''>%1-%2-%3  %4:%5:%6</t><br/><t size=''0.65'' align=''left'' color=''#aaaaaa''>category: %7</t><br/><br/><t size=''0.8'' align=''left''>%8</t><br/><br/><t size=''0.65'' align=''left'' color=''#aaaaaa''>actor: %9</t><br/><t size=''0.65'' align=''left'' color=''#aaaaaa''>details: %10</t>',
        _yy, _moStr, _ddStr, _hhStr, _mmStr, _ssStr,
        _entryCat, _desc, _who, str _details
    ];

    private _detail = _disp displayCtrl 1100;
    _detail ctrlSetStructuredText parseText _text;
"];

// Initial render reflects the default "All / All" combo state.
[_disp] call (_disp getVariable ["BO_auditViewerRender", {}]);
