# RAGS Rebuild Plan — from systems prototype to functional game

*Adopted 2026-06-11. This supersedes the "what's next" sections of PROGRESS.md.*

## Honest starting point

M0–M8 of `DESIGN.md` exist as **simulation systems verified by ~250 headless, function-level checks**. Phase 0/1 also has a scripted-input harness that exercises a narrow real input → UI → world loop and saves windowed screenshot checkpoints, plus focused real-scene checks for arrest, save/load rehydration, and long-session autosave endurance. The game has still never had a human playtest pass. The visuals have moved from flat rectangles to generated programmer-art placeholders, not final art. Human long-session play remains unproven. Jail, hospitals, marriage, and elections are a button plus a toast string. Minigames, factions, the radio DJ, build mode, six of twelve origins, and every origin's unique mechanic do not exist.

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
   - Started 2026-06-12: `tools/artgen/generate_assets.py` creates the first committed terrain atlas at `assets/tiles/terrain_atlas.png`; `TileWorld` loads it with a procedural fallback.
   - Continued 2026-06-12: the generated terrain atlas now includes sidewalk and dirt tiles, and `TileWorld` exposes them as walkable terrain.
2. **World rebuild:** `tile_world.gd` switches to atlas TileSets; buildings become facade+roof props with Y-sort and collision (roof fades when the player walks behind); `town.gd` re-laid out organically — winding roads, plazas, alleys, district flavors (Downtown + the Bricks core; the diner/store/bar strip; Site 9/docks edge); props everywhere. `interior.gd` rooms get real floors, walls, and furniture sprites.
   - Started 2026-06-12: generated door, shop-counter, and parked-car sprites now replace code-drawn polygons for those core interactables. Building facades, organic layout, roof depth, and broader prop coverage remain.
   - Continued 2026-06-12: generated building facade assets now cover roofs, front walls, lit/dark windows, awnings, and location signs. `Town.gd` layers them as non-colliding presentation sprites over the existing wall/nav shells. Organic layout, roof/player depth behavior, interiors, and broader street props remain.
   - Continued 2026-06-12: generated interior prop assets now cover the fridge, bed, shower, TV, bar, records desk, work spot, dealer, and fence, with existing interactions and collision preserved. Full-room composition, interior wall depth, furniture density, and better interior screenshot framing remain.
   - Continued 2026-06-12: generated street furniture now covers benches, street lamps, trash cans, dumpsters, and news boxes. Benches reuse `Amenity` rest behavior; decorative street props are non-colliding sprites. Organic layout, district-specific clutter, roof/player depth behavior, and broader prop density remain.
   - Continued 2026-06-12: `Town.gd` now paints sidewalks along road edges/building approaches and dirt service lots near Site 9/back-lot areas. More organic road geometry, district-specific clutter, roof/player depth behavior, and broader prop density remain.
3. **Characters:** `npc_agent.gd` and `Player.tscn` render paper-doll animated sprites (4-direction walk); NPC looks derive from `appearance_tags`; the player's outfit changes the sprite.
   - Started 2026-06-12: generated 32x48 body/outfit layers now replace placeholder player and NPC polygons. NPC archetype color tints the outfit layer; directional animation and outfit-specific player visuals remain.
   - Continued 2026-06-12: generated 4-direction x 4-frame walk sheets now drive player and embodied NPC body/outfit layers from movement velocity. Outfit-specific player visuals beyond the default outfit, more body variation, and richer idle states remain.
   - Continued 2026-06-12: the player outfit layer now follows the worn clothing flag, with generated walk sheets for the hoodie, thrift blazer, nice suit, and ski mask. More clothing coverage, body/hair variation, and richer idle states remain.
4. **Click-to-move** on the player (NavigationAgent2D): click ground = walk, click Interactable = walk-then-interact. WASD unchanged.
   - Started 2026-06-12: `Player.tscn` has a `NavigationAgent2D`; click ground movement works, click-to-interact follow-through is covered by the Phase 0 smoke harness, and WASD cancels the path.
5. **UI shell:** a `UIStack` manager node in Main (not an autoload) owning modal open/close and a single source of clock-pause truth — fixes the six-modals-each-pausing-the-clock hazard. Esc opens a pause menu (Resume / Save / Walk Away / Settings / Quit) instead of hard-exiting to the main menu. Consistent theme from `assets/ui/`.
   - Started 2026-06-12: `UIStack` now owns modal open/close, named clock pause locks, the Esc pause menu, generated command icons, and a runtime dark UI theme. Broader custom UI art and pixel-font work remain.
   - Continued 2026-06-12: the pause-menu Walk Away button is now exercised by the UIStack smoke suite, proving the UI path converts the controlled life into a persistent NPC before deferred character creation.
   - Continued 2026-06-12: `LegacyHandoffSmokeTest.tscn` now drives the real character creation UI after Walk Away and verifies the next life rejoins the existing town with the former-player NPC intact.
   - Continued 2026-06-12: `DeathHeirSmokeTest.tscn` now drives the real death screen heir button and verifies the grown child inherits into the same persistent town.
   - Continued 2026-06-12: `RealSaveLoadSmokeTest.tscn` now drives the real main scene, pause-menu Save button, disk load, and fresh Main rehydration for an interior save with player, NPC, crime, clock, and Gazette state intact.
   - Continued 2026-06-12: save loading now falls back to the `.bak` ironman file if the primary save is corrupt or missing, with real-scene coverage for both cases.
   - Continued 2026-06-12: the M3 save round-trip smoke now uses `SaveSlotGuard`, so broad survival regression runs no longer overwrite a local ironman slot.
   - Continued 2026-06-12: `LongSessionSmokeTest.tscn` now runs the real main scene across ten in-game days with autosaves, `.bak` creation, day 3/7/10 reloads, and Monday rent persistence. Daily autosaves now run deferred and coalesced so saved data reflects completed day systems.
6. **Playtest harness:** `scripts/dev/playtest_driver.gd` injects real InputEvents to run scripted playthroughs windowed and dumps screenshots at checkpoints (spawn → walk to diner → enter → interact → phone → shop). Everything it surfaces gets fixed.
   - Started 2026-06-12: `PlaytestDriver.tscn` validates spawn → movement → diner travel → phone → inventory → store travel → shop interaction → pause menu. Headless runs validate flow; windowed runs dump PNG checkpoints under `user://playtests`.
   - Continued 2026-06-12: interior checkpoint framing now resets camera smoothing after harness teleports, moves to a representative diner room view, and captures the store counter before opening the shop modal.
- **Definition of done:** the town reads as a 3/4 pixel-art town in screenshots; both control schemes work; every existing modal opens/closes with no pause or input conflicts; M1–M8 suites still green.

### Phase 1 — Social + Reality Check to 100%
- Dialogue as a real scene: portrait, name, relationship state, the streetwise read as an italic inner voice, intent menu with visible odds.
  - Started 2026-06-12: generated 64x64 archetype portraits now render in the dialogue UI beside the relationship/read/intent menu. Individualized portraits, stronger composition, and full Reality Check theater remain.
  - Continued 2026-06-12: dialogue now stages conversations over a subtle scrim so the live world remains visible without fighting the portrait, read, rumor, result, and action controls.
- **The Reality Check moment as theater:** the on-screen odds visibly re-roll and collapse (90% → 4%) with a sting; aftermath lines; witnesses turn to look.
  - Started 2026-06-12: dialogue now renders a dedicated Reality Check callout with perceived-to-actual odds collapse text and aftermath flavor, and the scripted playtest forces/captures the moment through the real dialogue UI. Button-level odds animation and visible witness reactions remain.
  - Continued 2026-06-12: social witnesses now keep a timed reaction state; embodied NPCs pause, face the target, and show a `!` cue while reacting. Stronger animation/camera staging remains.
  - Continued 2026-06-12: Reality Check events now pulse the player camera and bias toward an embodied target when available. Button-level odds animation, audio sting, and deeper aftermath animation remain.
  - Continued 2026-06-12: the collapsed action button now gets a red odds-collapse treatment and pulse when Reality Check reveals the true odds. At this stage, audio sting and deeper aftermath animation remained.
  - Continued 2026-06-12: the asset generator now writes a short Reality Check sting, and the main scene plays it through the production event path. Deeper aftermath animation remains.
  - Continued 2026-06-12: the target of a Reality Check now gets a called-out reaction state, faces the player when embodied, and shows a stronger `!!` cue. Richer multi-NPC aftermath choreography remains.
- Gossip made visible: NPCs reference what they heard with source flavor; the phone gets a People app (relationships, hearts/daggers, who's dating whom).
  - Started 2026-06-12: the phone now has a People tab backed by `NPCRecord` relationships, dating flags, top gossip memories, and NPC-to-NPC bonds/feuds. Player-knowledge gating and richer couple/family records remain.
  - Continued 2026-06-12: dialogue now previews a compact Memory/Rumor line when the NPC already knows a salient player story, including source-chain flavor and player-facing phrasing.
  - Continued 2026-06-12: secondhand gossip now records the NPC source, and both chat lines and the phone People tab name who passed the story along with relationship-flavored skepticism/trust. Player-knowledge gating remains.
  - Continued 2026-06-12: two-hop gossip now shows a compact source chain in chat and the People tab, so players can see when a story came through another NPC. Longer archive/history views remain.
  - Continued 2026-06-12: People rows now include a compact recent-stories line with multiple salient memories, including source-chain flavor. Longer archive/history views remain.
  - Continued 2026-06-12: new-world generation now enforces unique NPC display names, so People rows, gossip lines, and playtest screenshots do not collapse distinct townsfolk into duplicate names.
  - Continued 2026-06-12: People rows now surface compact social circles, listing up to two close ties and two feuds from each visible contact's NPC relationship graph.
  - Continued 2026-06-12: the People tab now shows known contacts only and hides unknown townsfolk until relationship, dating, or memory state gives the player a reason to know them. Broader NPC family records remain.
  - Continued 2026-06-12: known spouses now show family context in People, including player children when the spouse is listed. Broader NPC family networks remain.
- Dating becomes activities (a drink at the Anchor, a meal at Mel's — short scenes with choices), not a button.
  - Started 2026-06-12: dating now unlocks named activities (`Date: meal at Mel's`, `Date: drink at the Anchor`) instead of generic spend-time, with venue-specific time skips, need effects, relationship gains, and memories.
  - Continued 2026-06-12: date activities now request the live world travel path before resolving the venue date, keeping the active scene and saved player location in sync.
  - Continued 2026-06-12: the dialogue UI now opens venue date scenes with three player choices at Mel's or the Rusty Anchor, and each choice has distinct relationship/need/memory outcomes.
  - Continued 2026-06-12: date choices now read NPC personality and vice flags, producing small relationship/need modifiers plus result-text and memory flavor when the choice fits or grates. Deeper multi-step date scenes and broader balance remain.
- People Reader perk reveals true stats in the read line. Balance pass on all social odds.
  - Started 2026-06-12: `Perception.read_line()` now gives People Reader a true-stat readout (`STR/DEX/CON/INT/WIS/CHA`) in dialogue, with M4 coverage for the visible text. Full social odds balance remains.
  - Continued 2026-06-12: M4 now has social odds guardrails for average, favorable, and hostile interactions, and the chance spread was widened so strong social builds help without immediately pinning the 95% cap. Broader play-balance telemetry remains.
- **DoD:** scripted playthrough covering chat → flirt → reality check → hearing about it from a stranger later.
  - Started 2026-06-12: `PlaytestDriver.tscn` now drives chat -> flirt -> forced Reality Check -> sourced gossip from a stranger through the real dialogue UI. Full balance and human play checkpoint remain.

### Phase 2 — Survival loop to 100%
- Origin opening beats (arrive by bus / wake behind the gas station…), HUD goal tracker fed by the existing `LifePaths`, tutorialized first day.
  - Started 2026-06-12: the HUD now shows the current Life Path blocker as a compact objective. `LifePaths` includes a First Week path for getting hired, keeping rent ready, and staying fed before longer-term goals.
  - Continued 2026-06-12: First Week now includes an explicit first-shift blocker after hiring, so the HUD keeps new players on the survival loop until they actually earn a paycheck.
  - Continued 2026-06-12: origin `starting_location_id` now drives exterior start markers for first lives, and Main emits a once-per-life opening beat naming the origin/start place and pointing players to the HUD objective.
- Work shifts become visible montages (fast clock, workplace vignette, mid-shift dilemmas); sleeping/eating get fades and feedback.
  - Started 2026-06-12: `WorkShiftSmokeTest.tscn` now verifies a real diner work-spot interaction through player input, including shift-end time skip, pay, shift count, skill XP, and optional dilemma pause handling. Early clock-ins now skip to the actual shift end instead of ending early.
  - Continued 2026-06-12: inventory food use now reports concrete need gains and calories logged, with scripted playtest coverage for pressing the real Use button and consuming a food item.
  - Continued 2026-06-12: the scripted playtest now buys food through the real shop UI, verifying the store path spends cash and delivers inventory before survival balance relies on that loop.
  - Continued 2026-06-12: rest amenities now report concrete time/need results. `RestAmenitySmokeTest.tscn` covers a real bed interaction through player input and verifies sleep reaches 7 AM without pause leaks.
  - Continued 2026-06-12: work spots now announce the shift fast-forward duration and end time before clock-out, with HUD-toast coverage in the real work-shift smoke test. Full montage staging remains.
- Balance via a headless bot-week telemetry run tuned to DESIGN.md §6.7: the dishwasher week is survivable but tight.
  - Started 2026-06-12: `EconomyTelemetrySmokeTest.tscn` now guards the dishwasher-week baseline with production shift pay, food spending, Monday rent, and a bounded weekly margin.
- **DoD:** "survive a week as a dishwasher" is genuinely playable and paced.

### Phase 3 — Crime + police to 100%
- In-world verbs: pickpocket (proximity/behind), shoplifting under clerk sightlines, street carjacks; fence/dealer as scenes.
- Cops visibly patrol; wanted = embodied pursuit (chase AI) → arrest confrontation; jail becomes a real interior with a daily event loop (yard / library / kitchen) instead of a toast.
  - Started 2026-06-12: `InPlayArrestSmokeTest.tscn` now proves the real crime-to-warrant-to-embodied-cop arrest flow opens the production confrontation, serves time, clears wanted stars, and returns control to play. Chase AI and walkable jail remain.
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
