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

**Prototype foundation, in active development.** Sections 1–24 of the external build guide have
been statically reconciled against the project; Section 25 is the current development step.
Gameplay has not been rerun as part of this documentation audit. Content and balance are still
prototype quality. The procedural map and sector generator exist, but the
campaign coordinator and complete warp/run flow described by later guide sections are not yet
connected.

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
  persists.
- **Forward-fire projectiles** with team filtering, wrapped travel, and a lifetime cap.
- **Enemy AI with two styles** — `STRAFE` keeps its nose on the player while adding tangential
  drift and kites around a preferred range; `CHARGE` closes hard and eases off at point-blank.
  Shared aggro across a `PatrolGroup`.
- **World encounters** — patrol groups, a drifting caravan with a route, and a stationary
  outpost that defends territory and reinforces when alerted.
- **Sensors** — range-limited contact list on a refresh timer, with contact metadata driving
  colour-coded minimap markers. Nebula fields degrade sensor range while you are inside them.
- **Module buildcraft** — hull, shields, fire rate, damage, thrust, and sensor range effects,
  installed into a per-ship slot budget.
- **Pilot abilities** — data-driven, currently `DASH` (a forward impulse on cooldown).
- **Station** — paid hull repair plus a randomised store that rolls offers from YARD module
  categories.
- **HUD** — hull/shield/credits/sensor/mission/pilot readouts, minimap, settings panel, and a
  completion panel.
- **World simulation** — `advance_world()` ticks on sector transition: the caravan advances its
  route, an alerted outpost gains reinforcements, and the optional objective expires on a
  deadline. Known caravan position goes stale deliberately — your map shows what you last saw,
  not what is true.
- **Dev-mode console** with run-status, credit-granting, module-testing, and reset commands.
- **Visual effects** — procedural starfield and shield shader; nebula visuals use a shader while
  a separate `Area2D` supplies sensor interference.

### Implemented foundations not yet connected to the campaign loop

- `SystemMap` generates a seeded, one-way FTL route graph with unique node IDs and a fixed lower-
  right Warp node. `SectorGenerator` composes each destination from seeded actors and landmarks;
  the six authored sector scenes are layout fixtures, not campaign destinations.
- The map and generated-sector scene are not yet driven by the campaign coordinator. The project
  main scene remains `scenes/sectors/sector.tscn`, so the generated route is not reachable in the
  normal game flow yet. Do not treat static scene/resource inspection as proof of runtime play.

### Not yet implemented or still in progress

Section 25 discrete-world proof is in progress. Campaign integration and warp completion are
later guide steps. Meta-progression, factions as data, a mission framework, bosses, audio, and
additional ship and pilot rosters remain future work. See [design docs](#design-documents) for
the full intended scope.

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
on Lit, the developer console, Log.gd, and YARD. The other enabled addons provide editor tools.
F5 runs the current main scene (`scenes/sectors/sector.tscn`), which is still a prototype fixture
and not the completed campaign flow.

**Autoloads** (registered in `project.godot`): `SectorSpace`, `RunState`, `Console`,
`LitManager`.

---

## Working with the data layer

Content lives in **YARD registries**, addressed by **stable string ID** — never by file path.
This is the project's central content rule:

> Runtime code asks a registry for a resource by stable ID, or queries the registry by indexed
> property. It does not hold paths to individual resources.

The registry ID survives file moves and is what gameplay code stores. Three registries exist:

| Registry | Class restriction | Indexed property |
|---|---|---|
| `ships.tres` | `ShipDefinition` | — |
| `pilots.tres` | `PilotDefinition` | — |
| `modules.tres` | `ModuleDefinition` | `category` |

Current entries: 3 ships (`prototype_ship`, `corsair`, `cutter`), 1 pilot (`dash`), 6 modules
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

The design foundation, development roadmap, and full prototype build guide live outside this
repository, in the Downloads folder as HTML. They are the source of intent; this README
describes what the code actually does.

---

## Credits and licensing

Project code is **MIT** — see [LICENSE](LICENSE). Asset and addon rights are not all the same as
the project-code license. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for source,
author, verified terms, required notices, and unresolved items. The downloaded ship sheets and
portal sheet still need their original sources or licenses confirmed before redistribution.
The animated world-object sheet is identified as SteelSoldier's Top Down Sci-fi Tileset and
requires credit with a link if used. The Godot Engine copyright and license texts are included
at the project root.
