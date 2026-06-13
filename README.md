# Better Overthrow

Expansion mod for [Overthrow Community Edition](https://github.com/rekterakathom/Overthrow). Adds teams, banking, automated logistics, HAL AI commanders, FOB jobs, and many freedom-expansion features.

## Phase 1 status

**Implemented (this drop):**

- Mod scaffold + CfgFunctions registry + CBA preInit/postInit wiring
- Logging system (`BO_fnc_log`) with level filtering, subsystem allowlist, ERROR → systemChat mirror
- Audit system (`BO_fnc_audit`, `BO_fnc_auditServer`, `BO_fnc_auditGroup`) with per-category FIFO buckets, daily archival, audit viewer
- Save migration (`BO_fnc_migrateFromOT`) — vanilla OT save auto-converts on first BO load
- Post-load hydrate (`BO_fnc_postLoadHydrate`) — reattaches per-object BO state after load
- Backup slot + integrity stamp
- Team data model + 20 team operations (form, invite, kick, leave, disband, promote, demote, transfer leadership, set/get relation, audit, etc.)
- Per-team treasury (replaces global resistance funds)
- Town ownership system (`BO_townOwner_<town>`)
- Player team membership + bank balance via extended `savePlayerData`
- Reconnect handling with validation (disbanded team / kicked-while-offline detection)
- ATM system: deposit, withdraw (2% fee, 5% in NATO-controlled), transfer-to-player (1% fee), transfer-to-team-treasury (no fee), wanted flag on large NATO withdrawals
- Buildable factory + per-object production state (queue/producing/producetime stored on the anchor)
- Per-factory production tick (`BO_fnc_factoryProductionTick`) — multiple factories run independently
- Arsenal-strip fix (snapshot-and-diff for `openArsenal`, `editLoadout`, `editPoliceLoadout`)
- Per-player loadouts with named templates + copy-from-teammate + reset-to-default
- Per-body garbage collector (proximity-based, 1hr default decay)
- Modded item pricing fix — layered resolver with magazine equivalence, faction average, category-clamped heuristic
- Curated price packs for RHS, CUP, 3CB
- Modder API: `BO_basePrice` and `BO_tier` config attributes
- Admin price override (`BO_fnc_setPrice`)
- Team-tagged camps (extends OT fast travel)
- War Level HUD (surfaces `NATOresources` as 0-10 dial)
- FOB jobs in Y menu (existing context-aware button slot, bank-routed rewards)
- Minimal one-shot trucking with auto-deduction + delivery timer
- Per-team map markers (town stability marker colored by owning team)
- 21 OT function overrides registered (wantedSystem stays at OT default — Better Overthrow is PvE co-op, no team-vs-team)

**Known limitations of this Phase 1 drop:**

1. **Not in-game tested.** Code was written carefully against OT source but has not been compiled and run in Arma 3. First in-game run will surface bugs. Expect to iterate.
2. **OT mainMenu / fastTravel overrides delegate to OT originals via `compileScript`.** This works for content not requiring tight integration. A Phase 1.1 patch should replace these delegations with direct code copies modified in-place — needed if any of those OT files are themselves modified.
3. **GUERLoop input-output business handler is abbreviated.** The `count _data isEqualTo 4` branch in the GUERLoop override is shorter than OT's original. Final implementation should copy that block from OT verbatim with treasury routing — this is a 30-line addition that didn't fit cleanly into the abridged version.
4. **No dedicated dialog HPP files yet.** Every Phase 1 UI uses `OT_fnc_playerDecision` (which extends OT's existing decision dialog). Phase 2 adds full custom dialogs for the logistics rule editor, full audit viewer with pagination, and team management panel.
5. **No `ui/icons/logo_bo.paa`.** Logo referenced in mod.cpp doesn't exist yet — needs to be authored.
6. **Some override files delegate to OT via `compileScript` of the OT path** to avoid duplicating large bodies of code. If OT updates those files in a future release, our overrides will silently pick up the new behavior — which is mostly good but worth flagging.
7. **`BO_fnc_buildFactory` integration with `OT_Buildables`** still needs to be wired in by extending `OT_Buildables` at preInit with a new entry that calls `BO_fnc_buildFactory` as its init function. See `init/fn_preInit.sqf` for where to add this.

## Quick start

1. Place `@Better Overthrow/` alongside `@Overthrow Community Edition` in your mods folder.
2. Launch Arma 3 with both mods enabled (in this order): `@CBA_A3;@ace;@Overthrow Community Edition;@Better Overthrow`.
3. Load any Overthrow mission. On first run, BO detects the lack of `BO_dataVersion` and runs migration — a default team "The Resistance" is formed containing all existing generals with the global resistance funds as its treasury.
4. From here, regular OT play works, but with team-based mechanics and the additions above.

## Testing checklist

When you first run BO in-game:

- [ ] `.rpt` file shows `[BO][INFO][init] Better Overthrow preInit` lines on mission start
- [ ] `.rpt` file shows `[BO][INFO][init] Better Overthrow server postInit complete`
- [ ] Team data exists (check via debug console: `count keys (server getVariable ['BO_teams', createHashMap])`)
- [ ] Open arsenal at the spawn ammo box — you should keep your gear after close
- [ ] Recruit a unit — should use your saved per-player loadout (if any)
- [ ] Visit a cash register — "Use ATM" ACE action should appear
- [ ] Kill an enemy — body should have `BO_deathTime` set (check via debug console)

If any of these fail, grep the `.rpt` for `[BO][ERROR]` or `[BO][WARN]` lines and report back.

## File layout

```
@Better Overthrow/
├── mod.cpp                              # mod manifest
├── meta.cpp
├── README.md                            # this file
├── keys/
└── addons/
    └── BO_main/
        ├── $PBOPREFIX$                  # = "BO_main"
        ├── config.cpp                   # CfgPatches + CfgFunctions
        ├── CfgFunctions.hpp             # function registry
        ├── script_component.hpp         # main include
        ├── script_mod.hpp
        ├── script_version.hpp
        ├── STYLE.md                     # RULE 0 enforcement guide
        ├── MODDER.md                    # modder API guide
        ├── headers/
        │   ├── script_macros.hpp
        │   ├── exception_macros.hpp
        │   └── log_macros.hpp
        ├── functions/
        │   ├── init/                    # preInit, postInit, installOverrides
        │   ├── log/                     # BO_fnc_log, audit, recordMetric
        │   ├── save/                    # migration, hydrate, backup
        │   ├── team/                    # 20 team operations + treasury
        │   ├── town/                    # town ownership
        │   ├── atm/                     # banking
        │   ├── factory/                 # buildable factories + production tick
        │   ├── cleanup/                 # garbage collector
        │   ├── loadout/                 # per-player loadouts
        │   ├── economy/                 # pricing resolver
        │   ├── logistics/               # minimal trucking
        │   ├── player/                  # wanted tweak helpers
        │   ├── map/                     # team markers
        │   ├── UI/                      # War Level HUD
        │   ├── UI/dialogs/              # team / FOB / audit / loadout dialogs
        │   └── overrides/               # OT function overrides (22 files)
        ├── prices/                      # curated mod price packs
        │   ├── rhs.sqf
        │   ├── cup.sqf
        │   └── 3cb.sqf
        └── ui/
            ├── overrides.hpp
            └── icons/
```

## Logging and debugging

All BO output is prefixed `[BO]` in the `.rpt`. To filter:

- Errors only: grep `[BO][ERROR]`
- Subsystem-specific: grep `[BO][.][team]` (or factory, hal, save, etc.)

Mission params:
- `bo_log_level` — DEBUG / INFO (default) / WARN / ERROR
- `bo_log_subsystems` — comma-separated allowlist; empty = all

In-game audit viewer: access via the team dialog → "Audit log" entry.

## What comes next (not in this drop)

Per the [PLAN.md](../PLAN.md) at the project root:

- **Phase 2**: Buildable production businesses, persistent garage, full virtual trucking with rule engine, MHQ, recon flights, callable artillery/CAS, civilian saboteur events, world demand events, Team HAL, 23 new FOB mission types.
- **Phase 3**: NATO HAL replaces the existing NATO scheduler with a planner that adapts to your team's operations. (No team-vs-team AI war — Better Overthrow is PvE only.)
- **Phase 4**: Map porting auto-detection, manifest system, community map registry, `BO_fnc_dumpMapData`.

## License

Same as Overthrow Community Edition. Contributions welcome.
