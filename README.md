# RAGS

*Everyone starts in rags. Riches optional.*

A dark-comedy single-player life sim - **Sims x GTA x Second Life** - where every origin story starts you poor, every bonus has a price, and the town remembers everything. Permadeath in a persistent world: your next character walks past your last one's grave.

Built solo in **Godot 4.x** (GDScript), 2D top-down, 32px generated programmer-art pixel style.

## Signature systems

- **Origins are classes** - from 1-star "Off the Bus" to 5-star "Rock Bottom," every start is poor, just differently poor
- **Reality Check** - the UI shows your character's stereotype-based guess at NPC stats, not the truth. Watch your 90% collapse to 0% when the librarian catches your punch
- **Permadeath, persistent world** - die (or Walk Away) and re-roll into the same town; consequences, graves, and grudges remain
- **Deal Me a Life** - coherent random characters: the buff dockworker rolls STR-heavy, because the same stereotype table builds NPCs and fuels your misjudgments of them

## Running

Open the project in Godot 4.4+ and run, or:

```bash
godot --path .
```

Dev smoke tests: `godot --headless --path . res://scenes/dev/M8SmokeTest.tscn`
UI/modal regression: `godot --headless --path . res://scenes/dev/UIStackSmokeTest.tscn`
In-play arrest regression: `godot --headless --path . res://scenes/dev/InPlayArrestSmokeTest.tscn`
Real save/load regression: `godot --headless --path . res://scenes/dev/RealSaveLoadSmokeTest.tscn`
Long-session regression: `godot --headless --path . res://scenes/dev/LongSessionSmokeTest.tscn`
Save-slot regressions touch the same protected ironman files; run them serially, not in parallel.
Economy telemetry regression: `godot --headless --path . res://scenes/dev/EconomyTelemetrySmokeTest.tscn`
Dishwasher week regression: `godot --headless --path . res://scenes/dev/DishwasherWeekSmokeTest.tscn`
Work shift regression: `godot --headless --path . res://scenes/dev/WorkShiftSmokeTest.tscn`
Rest amenity regression: `godot --headless --path . res://scenes/dev/RestAmenitySmokeTest.tscn`
Opening beat regression: `godot --headless --path . res://scenes/dev/OpeningBeatSmokeTest.tscn`
Scripted playtest: `godot --headless --path . res://scenes/dev/PlaytestDriver.tscn` validates the flow; omit `--headless` to dump PNG checkpoints under Godot's `user://playtests`.
Generate art assets: `python tools/artgen/generate_assets.py`

## Controls

WASD move; click ground to walk; E interact; **Tab phone** (jobs, housing, people, bank, Mickey, health, paths, the Gazette); **I inventory**; Space pause; 1/2/3 speed; F3 debug overlay; Esc menu

## Status - systems prototype, not yet a playable game

The simulation layer for all of M0-M8 exists and passes about 250 **headless, function-level** checks (`godot --headless res://scenes/dev/M8SmokeTest.tscn`, suites M1-M8). That proves the math - paychecks, rent, evidence, saves - not the game. Phase 0 now has generated terrain/building/prop/character/UI art, click-to-move, centralized modal pause handling, and a scripted-input playtest harness with windowed screenshot checkpoints. It still has **not had a human playtest pass**, and several design-doc features are stubs (jail/hospital/marriage/elections are a button and a toast) or missing entirely (minigames, factions, radio DJ, build mode, 6 of 12 origins, the unique origin mechanics).

| Layer | State |
|---|---|
| Architecture (data-driven defs, record/view split, EventBus, ironman saves) | solid, tested |
| Simulation systems M0-M8 (economy, social/Reality Check, crime, housing, body, family, town) | implemented, headless-tested only |
| Interactive play (UI flows, modal layering, pacing, balance-by-feel) | scripted harness started; no human playtest yet |
| Art / audio / onboarding / game feel | generated programmer art started; audio/onboarding still absent |

**The path to a functional game is [`docs/REBUILD_PLAN.md`](docs/REBUILD_PLAN.md):** 3/4 angled perspective (Stardew-style), generated 32px pixel art (paper-doll characters, building facades, portraits), WASD + click-to-move, a UI/pause overhaul, a scripted-input playtest harness - then each system taken to interactively verified 100%, starting with Social + Reality Check.

Design bible: `docs/DESIGN.md`; Build log: `docs/PROGRESS.md`; Rebuild roadmap: `docs/REBUILD_PLAN.md`
