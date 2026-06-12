# RAGS — Build Progress

*Last updated: 2026-06-11 — **ALL MILESTONES (M0–M8) COMPLETE.** Repo: https://github.com/redstonejh/rags*

## Done & verified

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

Run tests: `godot --headless --path <abs> res://scenes/dev/M<N>SmokeTest.tscn` (N = 1..8; ~250 checks, all green).
Godot exe: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.6.3-stable_win64.exe`
IMPORTANT (headless): run `godot --headless --path <abs> --import` after adding new class_name scripts, or scenes hang on parse errors with no visible output.

## System map

- **Autoloads (7, unchanged):** EventBus, GameClock, ContentDB, WorldState, SimEngine, SaveManager, GameFlow.
- **Plain system Nodes in Main.tscn:** ShiftSystem, EconomySystem (drives Body daily ticks + stat drift), GossipSystem, CrimeSystem, TownLife. All EventBus-driven; headless tests instantiate them directly.
- **Static libraries:** Perception, Social, Confrontation, Body, Housing, LifePaths, Coherence, WorldGen, Locations.
- **Data (`data/**`, all .tres):** origins ×6, traits ×18, jobs ×8, items ×22, crimes ×8, housing ×6, furniture ×7, substances ×8, perks ×4, npc_archetypes ×11.
- **UI:** HUD (dynamic bars, toasts, wanted stars), phone (Jobs/Home/Bank/Mickey/Health/Paths/Town), shop, inventory, dialogue, dilemma, confrontation, death screen (obituary + heir), character creation (Life #N).
- **Saves:** versioned JSON, ironman; everything round-trips (sheet incl. substances/wounds/children/fame, NPCs incl. memories/age/alive, crime cases, gazette, town fear).

## Future polish ideas (beyond the design doc's roadmap)

Real art/audio (radio DJ), driving physics, factions as systems, more interiors (courthouse/casino/hospital), Dialogic conversations, remaining 6 origins (Widow, Prepper, Athlete, Cult Escapee, Amnesiac, Trust-Fund), build/furnish grid mode, stocks-lite. The architecture (records + data-driven defs + EventBus) is ready for all of it.
