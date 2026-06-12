# RAGS Rebuild Plan — from systems prototype to functional game

*Adopted 2026-06-11. This supersedes the "what's next" sections of PROGRESS.md.*

## Honest starting point

M0–M8 of `DESIGN.md` exist as **simulation systems verified by ~250 headless, function-level checks** — and that is all they are. The game has never been played interactively. The visuals are flat colored rectangles on an obvious grid. Several flows (heir, Walk Away, in-play arrest, modal UI stacking) have never executed outside unit tests that call functions directly with forced dice. Jail, hospitals, marriage, and elections are a button plus a toast string. Minigames, factions, the radio DJ, build mode, six of twelve origins, and every origin's unique mechanic do not exist.

What IS real: the architecture (data-driven `.tres` defs, record/view separation, EventBus, ironman saves that round-trip everything) and the signature mechanics implemented at the math layer (Reality Check perceived-vs-true odds, persistent-world permadeath, the witness pipeline). This is an engine, not a game. The plan below turns it into one.

## Locked decisions

- **Perspective: 3/4 top-down** (Stardew/Zelda-style — roofs AND building front faces, Y-sorted depth). NOT diamond isometric: all square-grid math, navigation, and positions stay; the *look* changes. Movement was never grid-locked; the "grid feel" is an art/layout problem and is fixed as one.
- **Controls: WASD + click-to-move.** Keep direct control, add Disco Elysium-style mouse navigation (click ground → pathfind there; click an NPC/object → walk over and use it). The nav mesh already exists on every walkable tile.
- **Graphics: generated pixel art** (32px tiles, ~32×48 characters, 64×64 portraits), produced by committed generator scripts. Honest ceiling: consistent, readable, atmospheric programmer-grade pixel art — palettes, dithering, shading — not hand-painted Disco Elysium. Verified by rendering scenes and reviewing screenshots.
- **Increments: each phase is taken to 100%** — feature-complete, *interactively exercised*, balanced, committed and pushed — before the next phase starts. "Done" claims require interactive verification, never just headless math.
- **First deep system after the foundation: Social + Reality Check** (the signature feature).

## The art pipeline (built once in Phase 0, reused by every later phase)

`tools/artgen/` — Python + Pillow scripts (seeded, deterministic, palette-driven) that write committed PNGs into `assets/`. Iteration loop: generate → load in a render scene → screenshot via the playtest harness → review the image → adjust.

| Asset set | Contents |
|---|---|
| `assets/tiles/` | terrain atlas: grass variants, road, sidewalk, dirt, interior floors, edge/transition tiles |
| `assets/buildings/` | facade kits per location: 2–3-tile-tall fronts (walls, lit/unlit windows, doors, awnings), roof tiles, rendered signage per business |
| `assets/chars/` | paper-doll layers, 4 directions × 4-frame walk cycles: body (skin tones) + hair + outfit — per archetype AND per clothing item, so the existing outfit/status system becomes visible on the sprite |
| `assets/portraits/` | 64×64 layered faces for dialogue, driven by the same `appearance_tags` the Coherence Engine already uses |
| `assets/props/` | cars, fridge, beds per furniture tier, counters, TVs, plants, benches, street lamps, gravestones |
| `assets/ui/` | 9-patch panels, phone frame, need/star/heart icons, OFL pixel font (fallback: generated bitmap font) |

Project settings: nearest-neighbor filtering, camera zoom ~2×, pixel-crisp stretch mode.

## Phases

Every phase ends with: headless suites green, scripted interactive playthrough passing, screenshots reviewed, a play checkpoint for a human, commit + push, PROGRESS.md updated with explicit "interactively verified: yes/no".

### Phase 0 — Foundation: look, feel, actually-playable
1. Art pipeline above, plus generated assets for everything currently on screen.
2. **World rebuild:** `tile_world.gd` switches to atlas TileSets; buildings become facade+roof props with Y-sort and collision (roof fades when the player walks behind); `town.gd` re-laid out organically — winding roads, plazas, alleys, district flavors (Downtown + the Bricks core; the diner/store/bar strip; Site 9/docks edge); props everywhere. `interior.gd` rooms get real floors, walls, and furniture sprites.
3. **Characters:** `npc_agent.gd` and `Player.tscn` render paper-doll animated sprites (4-direction walk); NPC looks derive from `appearance_tags`; the player's outfit changes the sprite.
4. **Click-to-move** on the player (NavigationAgent2D): click ground = walk, click Interactable = walk-then-interact. WASD unchanged.
   - Started 2026-06-12: `Player.tscn` has a `NavigationAgent2D`; click ground movement works, click-to-interact follow-through is covered by the Phase 0 smoke harness, and WASD cancels the path.
5. **UI shell:** a `UIStack` manager node in Main (not an autoload) owning modal open/close and a single source of clock-pause truth — fixes the six-modals-each-pausing-the-clock hazard. Esc opens a pause menu (Resume / Save / Walk Away / Settings / Quit) instead of hard-exiting to the main menu. Consistent theme from `assets/ui/`.
   - Started 2026-06-12: `UIStack` now owns modal open/close, named clock pause locks, and the Esc pause menu. Existing modal panels are wired through it; visual theme work remains.
6. **Playtest harness:** `scripts/dev/playtest_driver.gd` injects real InputEvents to run scripted playthroughs windowed and dumps screenshots at checkpoints (spawn → walk to diner → enter → interact → phone → shop). Everything it surfaces gets fixed.
   - Started 2026-06-12: `PlaytestDriver.tscn` validates spawn → movement → diner travel → phone → inventory → store travel → shop interaction → pause menu. Headless runs validate flow; windowed runs dump PNG checkpoints under `user://playtests`.
- **Definition of done:** the town reads as a 3/4 pixel-art town in screenshots; both control schemes work; every existing modal opens/closes with no pause or input conflicts; M1–M8 suites still green.

### Phase 1 — Social + Reality Check to 100%
- Dialogue as a real scene: portrait, name, relationship state, the streetwise read as an italic inner voice, intent menu with visible odds.
- **The Reality Check moment as theater:** the on-screen odds visibly re-roll and collapse (90% → 4%) with a sting; aftermath lines; witnesses turn to look.
- Gossip made visible: NPCs reference what they heard with source flavor; the phone gets a People app (relationships, hearts/daggers, who's dating whom).
- Dating becomes activities (a drink at the Anchor, a meal at Mel's — short scenes with choices), not a button.
- People Reader perk reveals true stats in the read line. Balance pass on all social odds.
- **DoD:** scripted playthrough covering chat → flirt → reality check → hearing about it from a stranger later.

### Phase 2 — Survival loop to 100%
- Origin opening beats (arrive by bus / wake behind the gas station…), HUD goal tracker fed by the existing `LifePaths`, tutorialized first day.
- Work shifts become visible montages (fast clock, workplace vignette, mid-shift dilemmas); sleeping/eating get fades and feedback.
- Balance via a headless bot-week telemetry run tuned to DESIGN.md §6.7: the dishwasher week is survivable but tight.
- **DoD:** "survive a week as a dishwasher" is genuinely playable and paced.

### Phase 3 — Crime + police to 100%
- In-world verbs: pickpocket (proximity/behind), shoplifting under clerk sightlines, street carjacks; fence/dealer as scenes.
- Cops visibly patrol; wanted = embodied pursuit (chase AI) → arrest confrontation; jail becomes a real interior with a daily event loop (yard / library / kitchen) instead of a toast.
- **DoD:** rob the QuikStop with and without witnesses and feel the difference; get chased; serve time.

### Phase 4 — Housing + furnishing to 100%
- Per-tier home interiors (cot hall → motel room → Bricks unit → decent apartment → house → penthouse), furniture placement mode in owned homes, furniture sprites per tier, comfort visualized.

### Phase 5 — Body + substances to 100%
- Visible states: drunk wobble and tint, LSD palette/post-FX, weight and age reflected on the paper-doll; clinic and hospital interiors; recovery meetings as scheduled place-events; withdrawal events.

### Phase 6 — Family, aging, legacy to 100%
- Spouse and kids at home with routines; wedding and funeral scenes; a graveyard with persistent graves **including your past characters**; heir and Walk Away flows fully exercised through the UI; the obituary as a rendered newspaper.

### Phase 7 — The living town endgame to 100%
- The Gazette as a readable paper + radio-style ticker; election campaign events; businesses as enterable, managed places; town fear visible on the street (boarded windows, empty nights); the feasible unique origin mechanics (the Exec's Rival NPC, the Gambler's Double-or-Nothing, the Tweaker's scavenge spots); generated SFX + ambient audio pass.

## Constraints

- The sim layer (`scripts/sim/*`, `scripts/autoload/*`) stays intact except for small UI hooks; all existing smoke suites must stay green throughout.
- Art and audio are generated: complete and consistent, programmer-art tier, and described as such.
- No phase is declared done without a passing scripted interactive test, a screenshot review, AND a human play checkpoint.
