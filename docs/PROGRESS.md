# RAGS — Build Progress

*Last updated: 2026-06-12. Repo: https://github.com/redstonejh/rags*

## Honest status: systems prototype — NOT yet a playable game

M0–M8 below are **simulation systems verified by headless, function-level tests only**. The game has never been play-tested interactively: every check calls functions directly with forced dice; no test (and no human) has driven the real input → UI → world loop. The visuals are placeholder rectangles. Jail/hospital/marriage/elections are button-plus-toast stubs; driving is a speed multiplier; minigames, factions, the radio DJ, build mode, 6 of 12 origins, and the per-origin unique mechanics don't exist yet. Known-risk untested areas: six modal CanvasLayers with independent input blockers and clock pause/restore that have never run together; Esc hard-exits to the menu from anywhere; the heir, Walk Away, and in-play arrest flows have never executed through the UI.

What IS solid: the architecture (data-driven defs, record/view separation, EventBus, ironman saves that round-trip everything) and the design's signature mechanics implemented at the math layer.

**The path from here to a functional game is `docs/REBUILD_PLAN.md`** — 3/4 angled perspective, generated pixel art, WASD + click-to-move, and one system at a time taken to interactively-verified 100%.

## Phase 0 progress

- **UIStack foundation started (2026-06-12):** `Main.tscn` now owns a `UIStack` node that centralizes modal open/close and named clock pause locks. Esc opens an in-game pause menu (Resume / Save / Walk Away / Settings placeholder / Quit to Menu) instead of immediately returning to the title screen.
- **Modal pause safety:** phone, inventory, shop, dialogue, dilemma, confrontation, and death screen flows now use composable pause locks, so closing one modal cannot accidentally resume time while another modal or manual pause is still active.
- **Click-to-move foundation:** `Player.tscn` now has a `NavigationAgent2D`; clicking walkable ground sets a path, clicking an interactable arms a walk-then-interact target, and WASD immediately cancels the click path to keep direct control authoritative.
- **Regression coverage:** added `UIStackSmokeTest.tscn`, which instantiates the real main scene, opens overlapping panels, verifies speed keys cannot break modal pause, checks Esc pause-menu toggling, and covers click movement, click-to-interact arrival, and WASD cancellation.
- **Scripted playtest harness:** added `PlaytestDriver.tscn`, which runs the real gameplay scene through spawn, movement, diner travel, phone, inventory, store travel, shop interaction, and pause-menu checkpoints. Headless mode validates flow and reports screenshot skips; windowed mode saves PNG checkpoints to `user://playtests`.
- **Playtest screenshot framing improved:** the playtest now resets camera smoothing after scripted teleports, moves to a useful diner room position before the interior checkpoint, and captures the store counter before opening the shop modal.
- **Generated art pipeline started:** `tools/artgen/generate_assets.py` deterministically writes `assets/tiles/terrain_atlas.png` (grass, road, floor, wall, solid floor). `TileWorld` loads that atlas while retaining the old procedural fallback.
- **Generated character sprites started:** the same art pipeline now writes layered 32x48 character sprites (`body_base`, player outfit, NPC outfit). `Player.tscn` and `NPCAgent.tscn` render those sprites, and NPC archetype color now tints the outfit layer.
- **Directional character animation started:** generated 4-direction x 4-frame walk sheets now drive the player and embodied NPC body/outfit layers. The playtest asserts that the player uses walk sheets and that movement advances the animation frame.
- **Generated prop sprites started:** doors, shop counters, and parked cars now use generated sprites from `assets/props/` with their existing collision and interaction behavior intact.
- **Generated building facades started:** `assets/buildings/` now contains generated roof tiles, wall/window facades, shop awnings, and per-location signs. `Town.gd` renders them through a non-colliding `FacadeLayer` over the existing building shells, preserving door registration, nav, and collision behavior.
- **Interior prop sprites started:** generated sprites now cover the fridge, bed, shower, TV, bar counter, records desk, work spot, dealer, and fence. Existing interactable behavior and collision stay intact through sprite-first/fallback rendering, and the scripted playtest now asserts that interior prop sprites spawn after entering the diner.
- **Street furniture started:** generated bench, street lamp, trash can, dumpster, and news-box sprites now populate the exterior. Benches use the existing `Amenity` rest behavior, while the other props render through a non-colliding `StreetPropLayer`; the scripted playtest asserts that street props spawn.
- **UI shell theme started:** generated pause-menu command icons now live in `assets/ui/`, and `UIStack` applies a consistent dark panel/button/label theme to gameplay UI controls as they are created.

## Systems implemented (headless-tested only — see status note above)

| Milestone | State |
|---|---|
| M0 walking skeleton | ✅ town, player, clock, needs, day/night, fridge, HUD |
| M1 character creation | ✅ ContentDB, origins, 18 traits, stat point-buy, trait budget, Deal Me a Life (Coherence Engine), ironman saves |
| M2 living NPCs | ✅ 190 NPCs with schedules/personalities, SimEngine abstract tick + embodiment LOD, doors/interiors, F3 overlay |
| M3 survival economy | ✅ jobs/shifts/paychecks + dilemmas, Monday rent + eviction, Big Mickey, body sim v1 (weight/calories/starvation), phone, shop/inventory, toasts, death → next life, ID-quest Life Path |
| M4 social + perception | ✅ Perception (perceived vs true stats, drunk confidence, streetwise reads), Social resolver w/ visible odds + Reality Check, dialogue UI, memories + gossip propagation, dating |
| M5 crime + police | ✅ crime catalog, CrimeCase pipeline (witnesses → reports → warrants @60), gossip→cop evidence, wanted stars, arrest/bail/bribe/jail, universal Confrontation (carjack → mercy/rob/kill), fence, permanent NPC death |
| M6 housing + status | ✅ T0–T5 wealth curve w/ poverty trap, gates (ID/deposit/outfit/history), credit score, home buying, furniture → quality + Mood, clothing as status + disguise |
| M7 body/substances/family/aging | ✅ 8-substance catalog (tolerance/addiction/OD/teeth/LSD), Recovery + Education paths, wounds that heal wrong, clinics + plastic surgery, aging (5d=1yr) + elder turnover, marriage → baby gauntlet → kid traits → heirs, obituaries, Walk Away, beater car |
| M8 the living town | ✅ TownLife (autonomous NPC events + NPC crime), the Rust Harbor Gazette, town fear equilibrium, fame/infamy, bodies + detectives, elections (buyable, dirty money welcome) + mayor police-budget lever, businesses + laundering, lifestyle stat drift, 3 new origins (Ex-Con/Gambler/Doctor) with Going Straight path, perks (Silver Tongue/Iron Liver/Brawler/People Reader) |

Run tests: `godot --headless --path <abs> res://scenes/dev/M<N>SmokeTest.tscn` (N = 1..8; ~250 checks, all green). Phase 0 regression: `godot --headless --path <abs> res://scenes/dev/UIStackSmokeTest.tscn`. Scripted flow: `godot --headless --path <abs> res://scenes/dev/PlaytestDriver.tscn` (omit `--headless` to dump PNG checkpoints).
Generate art assets: `python tools/artgen/generate_assets.py`.
Godot exe: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.6.3-stable_win64.exe`
IMPORTANT (headless): run `godot --headless --path <abs> --import` after adding new class_name scripts, or scenes hang on parse errors with no visible output.

## System map

- **Autoloads (7, unchanged):** EventBus, GameClock, ContentDB, WorldState, SimEngine, SaveManager, GameFlow.
- **Plain system Nodes in Main.tscn:** ShiftSystem, EconomySystem (drives Body daily ticks + stat drift), GossipSystem, CrimeSystem, TownLife, UIStack. Sim systems are EventBus-driven; headless tests instantiate them directly.
- **Static libraries:** Perception, Social, Confrontation, Body, Housing, LifePaths, Coherence, WorldGen, Locations.
- **Data (`data/**`, all .tres):** origins ×6, traits ×18, jobs ×8, items ×22, crimes ×8, housing ×6, furniture ×7, substances ×8, perks ×4, npc_archetypes ×11.
- **UI:** HUD (dynamic bars, toasts, wanted stars), phone (Jobs/Home/Bank/Mickey/Health/Paths/Town), shop, inventory, dialogue, dilemma, confrontation, death screen (obituary + heir), character creation (Life #N).
- **Saves:** versioned JSON, ironman; everything round-trips (sheet incl. substances/wounds/children/fame, NPCs incl. memories/age/alive, crime cases, gazette, town fear).

## Next: the rebuild

See `docs/REBUILD_PLAN.md` (adopted 2026-06-11): Phase 0 foundation (generated 3/4 pixel art pipeline, organic town re-layout, paper-doll characters, click-to-move, UIStack/pause-menu fix, scripted-input playtest harness), then phases each taken to interactively-verified 100% — Social/Reality Check first, then survival loop, crime/police, housing, body/substances, family/legacy, living-town endgame. Per-phase status will be tracked here with an explicit "interactively verified: yes/no".
