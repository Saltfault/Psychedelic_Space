# TBN — Psychedelic Space Game

*To Be Named. A forward-firing, open-space action roguelite in Godot 4.7.*

> The world takes itself seriously. The universe does not look serious.

You fly a ship that can only shoot where its nose points. Sectors are large, continuous, and
toroidal — no rooms, no wave timers, no arenas. Enemies exist in the world because they were
already there: patrols patrol, outposts defend, caravans travel with escorts. The tension is
never "can I win this fight" but **"how much of this system am I willing to risk before moving
on?"**

---

## Table of contents

- [Concept](#concept)
- [Design pillars](#design-pillars)
- [Current status](#current-status)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Getting started](#getting-started)
- [Working with the data layer](#working-with-the-data-layer)
- [Developer console](#developer-console)
- [Version control](#version-control)
- [Conventions](#conventions)
- [Credits and licensing](#credits-and-licensing)

---

## Concept

A run drops you out of a warp gate straight into the first sector — no hub, no preamble. You
navigate a branching chain of solar systems, and the last sector of each contains a warp gate
whose exact position you have to *find*, not merely reach.

Information is a resource. Your primary objective is always known, but everything else depends
on your sensors: landmark positions, patrol activity, merchant stations, side-quest
destinations, anomalies. A scout hull enters a sector knowing far more than a gunship does.
Sensor quality is a build decision, not a stat.

Combat is arcade and bullet-hell-adjacent, but it emerges from world geometry rather than
spawn logic. Dying is two problems on two timescales:

| Layer | Timescale | Recovery |
|---|---|---|
| **Shields** | Tactical | Regenerate after a short delay; boosters, pilot abilities, and modules restore them |
| **Hull** | Strategic | Persists across sectors; repaired only at stations or rare effects |

Entering the next system at low hull is a bet. So is leaving a system with credits unspent.

**Tonal target:** *The Expanse* if it were an acid trip. Serious fiction — war, scarcity,
espionage, colonial independence, corporate control — seen through fluorescent nebulae,
impossible accretion disks, and violently colourful hulls.

---

## Design pillars

1. **Space is a place, not a sequence of combat arenas.** Patrols, outposts, caravans, and
   discoveries exist naturally inside large continuous sectors.
2. **Movement is combat.** Forward-facing weaponry makes momentum, orientation, and positioning
   the core skill rather than a modifier on it.
3. **The player chooses how greedy to be.** Progress is always available; exploration and danger
   provide the power needed to survive later systems.
4. **Ships define mechanics; pilots break rules.** Hulls set handling and loadout structure;
   pilots introduce abilities that reshape a run.
5. **Runs create builds, not permanent power.** Modules are assembled within a run; permanent
   progression expands the pool of possibilities.
6. **The universe moves when you do.** Sectors advance world state in discrete steps on
   transition — no continuously simulated galaxy.

---

## Current status

**The campaign systems are implemented in the project source; gameplay verification is still pending.**
The implementation guide describes the campaign, solar-system themes, matching shader-rendered
planet landmarks, selectable ships and pilots, data-driven weapons, enemy roles, a phased outpost,
Event Audio, Juicee, and Conductor. These systems have not yet had a full gameplay acceptance run
after integration, so treat balance and end-to-end behavior as unverified until the acceptance
checks in the guide are completed.

### Implemented

- **Toroidal sectors** (8000×8000 default) with `wrap_position()` / `shortest_delta()` /
  `wrapped_distance()` used consistently by movement, AI, projectiles, and sensors — plus
  visual-only edge ghosting so wrapping reads correctly on screen.
- **Inertial flight** — thrust with command heading, linear drag, speed cap, and turn speed;
  controller stick aim with mouse fallback.
- **BaseShip composition** — one script backs player and AI alike; a controller sets
  `command_heading` / `command_thrust` / `command_fire`, and the ship does not care whether a
  human or an AI issued them.
- **Two damage layers** — shields absorb first and regenerate after a delay; hull overflow
  persists. Ram's forward shield is a separate finite-health component that blocks projectiles,
  damages enemies on contact, and recharges after use.
- **Forward-fire projectiles** with team filtering, wrapped travel, and a lifetime cap.
- **Enemy AI roles** — `STRAFE`, `CHARGE`, `INTERCEPTOR`, and `SNIPER` tactics share ship physics
  and patrol alerts. Each enemy needs its own current sensor contact to fire; lost contacts enter
  a no-fire search before disengaging.
- **World encounters** — patrol groups, a drifting caravan with a route, and a stationary
  outpost that defends territory and reinforces when alerted.
- **Sensors** — range-limited contact list on a refresh timer, with contact metadata driving
  colour-coded minimap markers. Nebula fields degrade sensor range while you are inside them.
- **Module buildcraft** — hull, shields, fire rate, damage, thrust, and sensor range effects,
  installed into a per-ship slot budget.
- **Pilot abilities** — data-backed Dash and Ram. Ram raises a forward-facing shield that blocks
  projectiles and damages enemies on contact; its separate shield meter recharges after use.
- **Station** — paid hull repair, a randomized YARD module store, side-by-side equipped and
  reserve inventories, drag sorting, and module resale.
- **HUD and menus** — hull/shield/credits/sensor/mission/pilot/weapon readouts, local map,
  combined equipment screen, ship statistics panel, pause/options menus, death and completion
  panels, and a seeded system route map.
- **World simulation** — `advance_world()` ticks on sector transition: the caravan advances its
  route, an alerted outpost gains reinforcements, and the optional objective expires on a
  deadline. Known caravan position goes stale deliberately — your map shows what you last saw,
  not what is true.
- **Dev-mode console** with run-status, credit-granting, module-testing, and reset commands.
- **Visual and audio effects** — procedural sector starfield, main-menu star shader, authored
  shield and ship sheets, imported shader planets, Event Audio event bank, system-specific
  Conductor tracks, and Juicee feedback.

### Campaign and content systems

- A new run enters ship selection and then builds a deterministic route through three authored
  solar-system resource themes. Each route node has its own stable ID, position, content role,
  solar-system metadata, and generation seed.
- `SystemMap` owns only adjacent-node travel and rejects transitions until the current sector is
  clear. The coordinator commits accepted transitions and advances the discrete world once.
- `SectorGenerator` composes destinations from their seed and role. Matching map body IDs select
  the same PlanetDefinition used by the in-sector planet scene and local sensor icon. Dedicated
  asteroid-ring nodes are labeled on the route map and generate dense, spaced rock clusters.
- Weapons can be swapped by pickup; enemies have authored role/weapon/pickup settings; the Outpost
  is a three-phase objective with a boss status display.

### Verification still required

The source has not been run as a game during this implementation pass. Complete the project's
deterministic map, save/continue migration, combat/drop, sensor, boss, audio, planet identity, and
accessibility acceptance checks in Godot before treating them as verified.
The YARD registries for the new resource types also need an editor scan so their stable-ID
indexes and Inspector dropdowns match the authored `.tres` files. Plugin/API availability and
asset terms are documented in [ASSET_CREDITS.md](ASSET_CREDITS.md) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

## Architecture

Two systems grow together: the **game simulation** and the **visual layer**. The rule that keeps
them apart:

> Shaders create the appearance of the universe. Nodes and scripts create the rules of it.

Anything whose position matters to gameplay — ships, bullets, collidable asteroids, stations,
pickups, objectives, and warp gates — is a real node. Nebula visuals are shader-driven, with a
separate gameplay `Area2D` controlling sensor interference; distant stars and background debris
have no collision.

### Ship composition

Ships are built by composition, never one monolithic script:

```
PlayerShip / EnemyShip            (CharacterBody2D, BaseShip)
├── Visuals
│   ├── Hull                      (Sprite2D, Lit receiver)
│   ├── ShieldVisual              (unshaded overlay)
│   └── EngineFlame               (thrust-dependent sprite strip)
├── CollisionPolygon2D
├── Muzzle                        (Marker2D — required; firing is disabled without it)
├── SensorComponent               (range-limited contact tracking)
└── Camera2D                      (player only)
```

A **controller** supplies intent; the ship owns physics, shields, weapons, and damage:

```gdscript
command_heading    # Vector2
command_thrust     # 0..1
command_fire       # bool
```

`PlayerShip` and `EnemyShip` share `BaseShip` rules. `Outpost` is a separate stationary objective
and defense actor, not a `BaseShip` subclass.

### Two clocks

Gameplay time and visual time are separate. A pilot ability that slows combat must not freeze
the starfield, so shaders read `visual_time` while simulation reads `delta`.

### World state advances discretely

`RunState.advance_world()` is called exactly once per accepted sector transition. That single
call is the whole living-universe simulation: no per-frame galaxy, no background processes.

---

## Repository layout

```
res://
├── addons/                     Third-party editor and runtime plugins
├── assets/
│   ├── data/
│   │   ├── ships/              ShipDefinition resources
│   │   ├── pilots/             PilotDefinition resources
│   │   ├── modules/            ModuleDefinition resources
│   │   └── registries/         YARD .tres registries (stable-ID indexes)
│   ├── fonts/
│   ├── licenses/               Third-party licence texts — keep with the assets
│   ├── shaders/
│   │   ├── backgrounds/
│   │   └── objects/
│   └── sprites/
│       ├── effects/
│       ├── projectiles/
│       ├── ships/
│       └── world/
├── scenes/
│   ├── debug/                  shader_lab.tscn — shader work without launching the game
│   ├── effects/
│   ├── enemies/
│   ├── sectors/
│   ├── ships/
│   ├── ui/
│   └── world/
├── scripts/
│   ├── autoload/               run_state.gd, sector_space.gd
│   ├── combat/
│   ├── data/                   Resource schema classes
│   ├── effects/
│   ├── enemies/
│   ├── ships/
│   ├── ui/
│   └── world/
├── godoban_boards/             Kanban boards (Godoban addon state)
├── build_info_demo/            Standalone editor/repository status sample
├── project.godot               Project config: autoloads, input map, physics layers
├── LICENSE                     MIT license for original project code
├── GODOT_LICENSE.txt           Godot Engine MIT license for distributed builds
├── GODOT_COPYRIGHT.txt         Godot and bundled engine dependency notices
├── THIRD_PARTY_NOTICES.md      Asset and addon sources, licenses, and release caveats
└── icon.svg
```

Only add subfolders when there is content to justify them.

---

## Getting started

**Requirements**

- **Godot 4.7.2** (Forward+ renderer — required by the Lit addon; Mobile and Compatibility are
  not supported)
- **git** with **git-lfs** on your `PATH`

**Setup**

```bash
git clone https://forgejo.hearthhome.lol/Saltfault/TBN-Psychedlic_Space_Game.git
cd TBN-Psychedlic_Space_Game
git lfs install          # required — binaries are LFS-tracked
git lfs pull             # fetch the actual binary content

# Enable lock verification so concurrent edits to locked files are rejected:
git config lfs."https://forgejo.hearthhome.lol/Saltfault/TBN-Psychedlic_Space_Game.git/info/lfs".locksverify true
```

Open the project in Godot 4.7.2. `project.godot` enables the bundled plugins; gameplay depends
on Lit, the developer console, Log.gd, YARD, Event Audio, Juicee, Conductor, and Input Helper.
The other enabled addons provide editor tools. F5 opens the main menu in
`scenes/ui/main_menu.tscn`; New Game leads through ship selection into the campaign. Run the
implementation guide's acceptance checklist after importing the project; source inspection alone does
not prove that the whole flow works in-engine.

**Autoloads** (registered in `project.godot`): `SectorSpace`, `RunState`, `Console`,
`LitManager`.

---

## Working with the data layer

Content lives in **YARD registries**, addressed by **stable string ID** — never by file path.
This is the project's central content rule:

> Runtime code asks a registry for a resource by stable ID, or queries the registry by indexed
> property. It does not hold paths to individual resources.

The registry ID survives file moves and is what gameplay code stores. The project includes
registries for ships, pilots, modules, weapons, planets, and solar systems. Ships and modules have
existing indexed entries; newer resource folders are configured as scan sources and must be
scanned/synced in YARD after the first editor import so the Inspector dropdowns and stable-ID maps
include all authored resources.

| Registry | Class restriction | Indexed property |
|---|---|---|
| `ships.tres` | `ShipDefinition` | — |
| `pilots.tres` | `PilotDefinition` | — |
| `modules.tres` | `ModuleDefinition` | `category` |
| `weapons.tres` | `WeaponDefinition` | — |
| `planets.tres` | `PlanetDefinition` | — |
| `solar_systems.tres` | `SolarSystemDefinition` | — |

Current entries: 3 ships (`prototype_ship`, `corsair`, `cutter`), 2 pilots (`dash`, `ram`), 6 modules
across `offense` / `defense` / `mobility` / `sensor` / `utility`.

**Adding a module** means adding a YARD entry and reindexing `modules.tres` — no code edit. The
store picks it up automatically.

Inspector dropdowns are wired with YARD's custom hint:

```gdscript
@export_custom(Registry.PROPERTY_HINT_CUSTOM, "res://assets/data/registries/ships.tres")
var ship_id: StringName = &"prototype_ship"
```

---

## Developer console

Ships enabled in release builds but **starts disabled**. Enable it from the HUD's settings panel;
the preference persists to `user://settings.cfg` and fails closed if the file is malformed.

| Command | Effect |
|---|---|
| `run_status` | Sector, world tick, and credit balance |
| `add_credits <amount>` | Grant credits for testing |
| `reset_run` | Reset run progress |
| `test_module <module_id>` | Install a YARD module on the player and report resulting stats |
| `list_modules <category>` | List module IDs in a category |

---

## Version control

Hosted on a self-managed **Forgejo** instance with **Git LFS** and **LFS file locking** enabled.

```
origin  https://forgejo.hearthhome.lol/Saltfault/TBN-Psychedlic_Space_Game.git
```

**What goes in LFS.** `*.png`, `*.jpg`, `*.psd`, `*.wav`, `*.ogg`, `*.glb`, `*.blend`, fonts,
and other binaries. Godot's **text** formats — `.tscn`, `.tres`, `.gd`, `.gdshader` — are
deliberately **not** in LFS so they stay diffable and mergeable.

**Locking.** Use it for binary assets and scenes you are actively editing, so a teammate's push
cannot silently overwrite your work:

```bash
git lfs lock assets/sprites/ships/player.png   # exclusive
git lfs locks                                  # what's locked, by whom
git lfs unlock assets/sprites/ships/player.png
```

**Never commit** `.godot/` (import cache) or addon migration backups. Both are already ignored.
`.uid` and `.import` sidecar files **must** be committed alongside the asset they describe.

---

## Conventions

- **Composition over inheritance.** Components over a script that does everything.
- **`BaseShip` owns shared behaviour.** Subclasses implement `_gather_commands()` and nothing
  else about physics.
- **Fail loudly, not silently.** Data-load failures log via `Log.error`/`Log.warn` and disable
  the affected node rather than proceeding with defaults.
- **Wrapped math everywhere.** Any distance that gameplay depends on uses
  `SectorSpace.shortest_delta()`; anything comparing positions across a sector edge that does
  not is a bug.
- **Transient actors belong to the sector.** Projectiles, pickups, and effects are parented
  through `SectorSpace.spawn_owned()` so they are freed with the sector they were spawned in,
  never to `get_tree().current_scene`.
- **Comment the *why*.** The code says what; comments explain intent and constraint.
- **Run the GDScript formatter** before committing (addon is enabled).

### Design documents

Design references and implementation instructions are maintained separately from this source
tree. This README describes the current code and project setup.

---

## Credits and licensing

Project code is **MIT** — see [LICENSE](LICENSE). Asset and addon rights are not all the same as
the project-code license. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for source,
author, verified terms, required notices, and unresolved items. The downloaded ship sheets and
portal sheet still need their original sources or licenses confirmed before redistribution.
The animated world-object sheet is identified as SteelSoldier's Top Down Sci-fi Tileset and
requires credit with a link if used. The Godot Engine copyright and license texts are included
at the project root.
