# RAGS

*Everyone starts in rags. Riches optional.*

A dark-comedy single-player life sim — **Sims × GTA × Second Life** — where every origin story starts you poor, every bonus has a price, and the town remembers everything. Permadeath in a persistent world: your next character walks past your last one's grave.

Built solo in **Godot 4.x** (GDScript), 2D top-down, 32px pixel art (placeholder shapes for now).

## Signature systems

- **Origins are classes** — from ★ "Off the Bus" to ★★★★★ "Rock Bottom," every start is poor, just differently poor
- **Reality Check** — the UI shows your character's *stereotype-based guess* at NPC stats, not the truth. Watch your 90% collapse to 0% when the librarian catches your punch
- **Permadeath, persistent world** — die (or Walk Away) and re-roll into the same town; consequences, graves, and grudges remain
- **Deal Me a Life** — coherent random characters: the buff dockworker rolls STR-heavy, because the same stereotype table builds NPCs and fuels your misjudgments of them

## Running

Open the project in Godot 4.4+ and run, or:

```
godot --path . 
```

Dev smoke tests: `godot --headless --path . res://scenes/dev/M8SmokeTest.tscn`
UI/modal regression: `godot --headless --path . res://scenes/dev/UIStackSmokeTest.tscn`
Scripted playtest: `godot --headless --path . res://scenes/dev/PlaytestDriver.tscn` validates the flow; omit `--headless` to dump PNG checkpoints under Godot's `user://playtests`.

## Controls

WASD move · click ground to walk · E interact · **Tab phone** (jobs, housing, bank, Mickey, health, paths, the Gazette) · **I inventory** · Space pause · 1/2/3 speed · F3 debug overlay · Esc menu

## Status — systems prototype, not yet a playable game

The simulation layer for all of M0–M8 exists and passes ~250 **headless, function-level** checks (`godot --headless res://scenes/dev/M8SmokeTest.tscn`, suites M1–M8). That proves the math — paychecks, rent, evidence, saves — not the game. It has **never been play-tested interactively**, the graphics are placeholder rectangles, and several design-doc features are stubs (jail/hospital/marriage/elections are a button and a toast) or missing entirely (minigames, factions, radio DJ, build mode, 6 of 12 origins, the unique origin mechanics).

| Layer | State |
|---|---|
| Architecture (data-driven defs, record/view split, EventBus, ironman saves) | ✅ solid, tested |
| Simulation systems M0–M8 (economy, social/Reality Check, crime, housing, body, family, town) | ✅ implemented, headless-tested only |
| Interactive play (UI flows, modal layering, pacing, balance-by-feel) | ❌ never exercised |
| Art / audio / onboarding / game feel | ❌ placeholders |

**The path to a functional game is [`docs/REBUILD_PLAN.md`](docs/REBUILD_PLAN.md):** 3/4 angled perspective (Stardew-style), generated 32px pixel art (paper-doll characters, building facades, portraits), WASD + click-to-move, a UI/pause overhaul, a scripted-input playtest harness — then each system taken to interactively-verified 100%, starting with Social + Reality Check.

Design bible: `docs/DESIGN.md` · Build log: `docs/PROGRESS.md` · Rebuild roadmap: `docs/REBUILD_PLAN.md`
