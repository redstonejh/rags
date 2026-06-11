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

## Status

| Milestone | State |
|---|---|
| M0 walking skeleton | ✅ |
| M1 character creation + data pipeline | ✅ |
| M2 living NPCs (200 simulated) | in progress |
| M3–M8 economy → crime → housing → family → living town | planned |

Design bible: `docs/DESIGN.md`
