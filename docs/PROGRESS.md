# RAGS — Build Progress

*Last updated: 2026-06-11 (M6 complete). Repo: https://github.com/redstonejh/rags*

## Done & verified

| Milestone | State |
|---|---|
| M0 walking skeleton | ✅ town, player, clock, needs, day/night, fridge, HUD |
| M1 character creation | ✅ ContentDB, 3 origins, 18 traits, stat point-buy, trait budget, Deal Me a Life (Coherence Engine), ironman saves, 16/16 smoke tests |
| M2 living NPCs | ✅ 190 NPCs with schedules/personalities, SimEngine abstract tick + embodiment, 6 enterable-or-abstract buildings + door travel, F3 overlay, 15/15 smoke tests |
| M3 survival economy | ✅ jobs/shifts/paychecks + dilemmas, Monday rent + eviction, Big Mickey, body sim v1 (weight/calories/starvation death), phone (Jobs/Bank/Mickey/Paths), shop + inventory UI, toasts, HUD v2, death → next life in the persistent town, ID-quest Life Path. 49/49 smoke tests |
| M4 social + perception | ✅ Perception (perceived vs true stats via the Coherence table, drunk confidence inflation, streetwise reads), Social action resolver w/ visible odds + Reality Check moments, dialogue UI on every embodied NPC, memories w/ salience + decay + cap, GossipSystem (hourly propagation + familiarity drift), dating v1. 31/31 smoke tests |
| M5 crime + police | ✅ CrimeDef catalog (8), CrimeCase records (UNREPORTED→OPEN→WARRANT→COLD, warrant @60), witness pipeline (id confidence × civic duty − friendship − fear + victimhood, forgettable_face halves), gossip→cop hearsay evidence, wanted stars + cop arrest confrontations, jail v1 (serve/bail/bribe-by-corruption), universal Confrontation (carjack gamble → fight/bluff/flee/beg → mercy/rob/kill), pickpocket/shoplift/register robbery, the fence, NPC death (permanent). 38/38 smoke tests |
| M6 housing + status | ✅ HousingDef T0–T5 (poverty trap intact: motel > bricks rent), gates (ID/deposit/outfit tier/employment-or-clean-rent), credit score (on-time +1, miss −5, eviction −15), buying (credit + down payment, mortgage = rent with a deed), FurnitureDef (bed/tv quality + comfort → Mood), clothing as status (outfit_tier) + disguise (ski mask ×0.3 witness ID), phone Home app. 33/33 smoke tests |

Run tests: `godot --headless res://scenes/dev/M1SmokeTest.tscn` (and M2/M3SmokeTest).
Godot exe: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.6.3-stable_win64.exe`

## M3 system map (for whoever builds M4)

- `scripts/sim/shift_system.gd` + `economy_system.gd` — plain Nodes in Main.tscn (NOT autoloads), all EventBus-driven so headless tests can emit signals at them.
- `scripts/sim/paths.gd` (`LifePaths.evaluate(sheet)`) — pure function, renders in the phone's Paths tab.
- Phone = Tab, Inventory = I (input actions "phone"/"inventory" in project.godot).
- `CharacterSheet.consume_item()` applies need effects + logs `flags.calories_today`; `Interactable.interact()` logs calories for fridge-style food too; `EconomySystem._body_tick()` turns calories into weight daily and kills below 45 kg.
- Death: `EventBus.player_died` → WorldState writes `alive=false` + saves (ironman) → main.gd shows death screen → character creation header says "Life #N" → `GameFlow.start_new_game` routes to `WorldState.start_life()` (town persists) vs `new_world()` (first life). `GameFlow.continue_game()` routes dead saves back to creation.
- Origins now carry `starting_housing_id` + `starting_flags` (exec: decent_apartment + 4 prepaid weeks).

## System map (for whoever builds M6+)

- M4: `scripts/sim/perception.gd` (perceived vs true stats), `scripts/sim/social.gd` (action resolver, forced_roll for tests), `scripts/sim/gossip_system.gd` (Node in Main; hourly propagation, daily memory decay; `share()` static). NPCRecord: `rel/change_rel/add_memory/knows_memory/top_gossip`, memories = plain dicts, cap 24. Embodied NPCs carry `NPCInteractable` → dialogue UI.
- M5: `scripts/sim/crime_system.gd` (commit/witness pipeline/warrants/jail, mostly static), `scripts/sim/crime_case.gd`, `scripts/sim/confrontation.gd` (standoff resolver; UIs in `scripts/ui/confrontation.gd`), `scripts/world/parked_car.gd` + `fence_spot.gd`. Crime memories carry `case_id`; gossip preserves it; cops convert hearsay to evidence daily. NPCRecord.alive — dead NPCs persist but stop ticking.
- IMPORTANT (headless): run `godot --headless --path <abs> --import` after adding new class_name scripts, or scenes hang on parse errors with no output.

**Standing instruction:** build ALL milestones (M6→M8 per docs/DESIGN.md roadmap), test headless each, commit+push each, infer answers from the design doc, don't stop. Don't add autoloads beyond the existing 7.

## Next: M6 housing → M7 body/family/aging → M8 living town (see docs/DESIGN.md Part 5 roadmap and Parts 6–7 for economy/crime numbers).
