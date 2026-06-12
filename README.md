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

Dev smoke tests: `godot --headless res://scenes/dev/M1SmokeTest.tscn`

## Controls

WASD move · E interact · **Tab phone** (jobs, housing, bank, Mickey, health, paths, the Gazette) · **I inventory** · Space pause · 1/2/3 speed · F3 debug overlay · Esc menu

## Status — all milestones shipped

| Milestone | State |
|---|---|
| M0 walking skeleton | ✅ |
| M1 character creation + data pipeline ("Deal Me a Life") | ✅ |
| M2 living NPCs (190 simulated, schedules, embodiment LOD) | ✅ |
| M3 survival economy (jobs, rent, Mickey, body sim, death → next life) | ✅ |
| M4 social + perception (Reality Check, gossip, memories, dating) | ✅ |
| M5 crime + police (witnesses, warrants, confrontations, jail, the fence) | ✅ |
| M6 housing + status (T0–T5, credit, furniture, clothing & disguise) | ✅ |
| M7 body/substances/family/aging (8 drugs, wounds, marriage → heirs, Walk Away) | ✅ |
| M8 the living town (Gazette, town fear, elections, laundering, perks, 6 origins) | ✅ |

Each milestone has a headless smoke suite: `godot --headless res://scenes/dev/M8SmokeTest.tscn` (M1–M8, ~250 checks total).

Design bible: `docs/DESIGN.md` · Build log: `docs/PROGRESS.md`
