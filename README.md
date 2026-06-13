# Better Overthrow

Better Overthrow is a standalone fork of [Overthrow Community Edition](https://github.com/rekterakathom/Overthrow) — a co-op revolution sandbox for Arma 3. You start as a lone insurgent on an occupied island and build a resistance: earn money, win over towns, capture territory, and drive the occupying military out. It plays as a persistent, save-anywhere campaign for one player or a co-op group.

Better Overthrow keeps the core Overthrow loop and layers on a deeper economy, persistent infrastructure, an adaptive enemy commander, and broad mod-faction support.

## Requirements

- **Arma 3**
- **CBA_A3**
- **ACE3**

Better Overthrow bundles its own copy of the Overthrow systems, so you do **not** need the separate Overthrow Community Edition mod. Load Better Overthrow **instead of** it.

Recommended launch order:

```
@CBA_A3 ; @ace ; @Better Overthrow
```

### Optional

- **LAMBS Danger.fsm** and **VCOM AI** are detected automatically and used to make enemy AI move and fight more convincingly. Neither is required — the mod runs fine without them.

## Supported maps

Altis · Malden · Tanoa · Livonia

## Installation

1. Subscribe to the mod (or place the `@Better Overthrow` folder in your Arma 3 directory).
2. Enable it in the launcher together with CBA_A3 and ACE3, in the order above.
3. Pick a Better Overthrow mission for the map you want and host or join it.

## Features

- **Banking & ATMs** — deposit, withdraw, and transfer cash between players. Big withdrawals at enemy-held banks can get you noticed.
- **Production economy** — build factories and businesses (lumberyard, mine, vineyard, winery, olive plantation, chemical plant) that turn raw materials into goods over time.
- **Automated logistics** — set up truck routes between cargo containers and let scheduled deliveries move stock for you, for a per-trip fee.
- **Persistent garage & insurance** — store vehicles safely and insure them so a loss isn't permanent.
- **Capturable police stations** — every enemy-held town has a police station you can storm and take for yourself; the enemy will try to take it back.
- **Recon flights** — pay for temporary intel that reveals enemy positions in a town, region, or map-wide.
- **Artillery & close air support** — high-command players can call fire missions and air strikes.
- **Civilian unrest** — informants and night-time saboteurs act on the resistance's behalf as your support grows.
- **World demand events** — shifting supply and demand spike buy and sell prices in different towns.
- **FOB jobs** — request side missions from your forward bases for cash and influence.
- **Adaptive enemy commander (HAL)** — the occupying force is run by a commander that reacts to your activity, hunts for you when you go quiet, matches its response to your strength, and knows when to reinforce or cut its losses. It only acts on what it has actually seen — no cheating.
- **Choose your enemy** — pick the occupying faction in the lobby: vanilla NATO or popular mod factions (RHS, CUP, 3CB and more). Garrisons, vehicles, and support all adapt to your choice.
- **High command (Generals)** — promoted players get Zeus-based command tools and access to artillery/CAS.
- **Full persistence** — save and reload your campaign at any time; your economy, captures, vehicles, and progress all carry over.
- **Quality-of-life** — audit log of what's happening across the campaign, saveable loadout templates, a War Level indicator, and corrected pricing for modded weapons and gear.

## Configuration

Most behaviour is tunable from the **lobby mission parameters** before the game starts, including:

- the occupying enemy faction,
- how active and aggressive the enemy commander (HAL) is,
- whether high-command tools and certain systems are enabled.

## Credits & license

Built on [Overthrow Community Edition](https://github.com/rekterakathom/Overthrow). Same license as upstream Overthrow.
