# RAGS — Build Progress

*Last updated: 2026-06-11 (mid-M3). Repo: https://github.com/redstonejh/rags*

## Done & verified

| Milestone | Commit | State |
|---|---|---|
| M0 walking skeleton | `34df1ed` | ✅ town, player, clock, needs, day/night, fridge, HUD |
| M1 character creation | `ae5dda1` | ✅ ContentDB, 3 origins, 18 traits, stat point-buy, trait budget, Deal Me a Life (Coherence Engine), ironman saves, 16/16 smoke tests |
| M2 living NPCs | `32a9866` | ✅ 190 NPCs with schedules/personalities, SimEngine abstract tick + embodiment, 6 enterable-or-abstract buildings + door travel, F3 overlay, 15/15 smoke tests |
| M3 survival economy | `c2aff6b` | 🟡 WIP — data + stations done, systems/UI not wired |

Run tests: `godot --headless res://scenes/dev/M1SmokeTest.tscn` (and M2SmokeTest).
Godot exe: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.6.3-stable_win64.exe`

## EXACTLY where M3 stopped

**Done this session (all parse-clean, M1+M2 tests green):**
- `scripts/resources/job_def.gd` + `data/jobs/*.tres` — 8 jobs, 4 ladders × 2 rungs, promotion chain fields
- `data/items/*.tres` — 7 new items (noodles, canned dinner, sandwich, energy drink, six-pack, candy, meth) with `cheap/junk/drug` tags
- `scripts/sim/needs.gd` — now 5 base needs + optional bars (`craving`) via `add_optional()`
- `scripts/sim/character_sheet.gd` — dirty_cents/bank_cents/mickey_debt_cents, inventory, job_id/shifts_worked, housing_id/rent_strikes, weight_kg, lives_lived, alive, flags, `mood()`, `skill_level()`/`add_skill_xp()`, origin hooks in `rebuild_needs_multipliers()` (champagne_taste ×1.6 fun, no_papers→has_id flag, addiction_meth→craving bar). to_dict/from_dict updated.
- `scripts/autoload/game_clock.gd` — `skip_minutes(n)` (synchronous fast-forward firing all signals)
- `scripts/autoload/event_bus.gd` — toast, shift_started/finished, shop_opened, path_updated, player_died, player_job_changed
- Station interactables (all `_init`-built, no scenes): `work_spot.gd` (validates job/day/shift-window then skips to clock-out, emits shift signals), `records_desk.gd` ($40 + 2-day ID quest, the no_papers gate), `shop_counter.gd` (emits shop_opened), `bar_counter.gd` ($8 drink), `amenity.gd` (bed/shower/TV/bench; bed gated on housing_id), `dealer_spot.gd` (meth $20, takes dirty cash first)
- `scripts/world/interior.gd` — interiors for loc_offices (work spots + records desk), loc_site (work spots + dealer), loc_bar (bar counter); bricks got bed/shower/TV (player unit); store got shop counter + work spot; diner got work spot. Locations defs updated: offices/site/bar now "interior".

**NOT done — the remaining M3 list, in build order:**
1. **ShiftSystem** (`scripts/sim/shift_system.gd`, node added to Main.tscn): listens shift_finished → pay wage (late penalty −25% if >30 min late), `add_skill_xp(job.trains_skill)`, shifts_worked++, promotion check (shifts ≥ min + skill req → offer next_job_id via toast/dialog), ~25%/shift dilemma event (small code table: choices → cash/mood deltas shown post-shift).
2. **EconomySystem** (`scripts/sim/economy_system.gd`, node in Main): on day_passed — Monday rent (bricks_unit $90/wk, decent_apartment $200/wk; can't pay → rent_strikes++, 3 strikes → housing_id="" + toast; exec flag rent_prepaid_weeks counts down first); Mickey interest +20%/wk on debt, debt > $1500 → beating event (energy −40, toast threat); body daily tick (weight from calories eaten that day — track `flags.calories_today`, reset daily; hunger==0 burns 0.4kg/day; weight<45 → `EventBus.player_died("starvation")`).
   - Calorie tracking hook: item consumption should add `flags.calories_today += hunger_restored*25` — wire where items are eaten (inventory UI).
3. **Phone UI** (`scenes/ui/Phone.tscn` + `scripts/ui/phone.gd`, CanvasLayer in Main; input action "phone" = Tab physical 4194306): tabs Jobs (list ContentDB.all_jobs() w/ req checks vs has_id/skills, Apply → job_id set + player_job_changed), Bank (needs has_id; balance, deposit/withdraw clean cash only), Mickey (borrow $100/$500 → cash + debt 1.2×? no: debt += amount, 20% added weekly; Repay button), Paths (render `paths.gd` output).
4. **paths.gd** (`scripts/sim/paths.gd`): static evaluate(sheet) → [{name, steps:[{label, done, current}]}] — "Getting Off the Street": has $40 → file at records desk → wait 2 days → has_id. Only shown for no_papers sheets. Listens nothing; phone re-renders on path_updated.
5. **Shop UI + Inventory UI** (`scripts/ui/shop.gd`, `scripts/ui/inventory.gd`, CanvasLayers in Main; input "inventory" = I key 73): shop listens shop_opened (buy → cash check → inventory.append); inventory lists counts, Use applies need_effects + calories, removes one.
6. **Toast UI**: add a Label queue to HUD (listens EventBus.toast, fades after 4s, stacks 3).
7. **HUD refactor**: build need bars dynamically from sheet.needs.values (incl. craving when present), add Mood label + weight + dirty cash ("+$X dirty") + job/shift indicator.
8. **Death flow**: listen player_died in main.gd → DeathScreen (simple CanvasLayer: cause + "The town continues without you." + Continue→character creation). **WorldState: split `new_game` into `new_world(sheet)` (current behavior) and `start_life(sheet)` (keeps npcs/world, lives_lived = prev+1)**; GameFlow.start_new_game should call start_life when WorldState.npcs not empty AND a death/walk-away happened (track WorldState.world_exists flag). Creation screen header: "Life #N in Rust Harbor".
9. **Origin starting housing**: add `starting_housing_id` @export to OriginDef + set in 3 origin .tres (off_the_bus="bricks_unit", fired_exec="decent_apartment" + flags rent_prepaid_weeks=4 — apply in character_creation start, rock_bottom=""). Wire into _on_start_pressed.
10. **M3 smoke test** (`scenes/dev/M3SmokeTest.tscn`): apply for dishwasher (no ID needed), simulate to shift, verify paycheck math + skill XP; Monday rent deduction + strike on broke; Mickey 20% interest; ID quest day-math; weight starvation death emits player_died; save round trip of all new sheet fields.
11. Commit as "M3: survival economy", push, launch game for user.

**Design notes for the implementer (me):** wage already in JobDef; weekday = `GameClock.day % 7` (0=Mon); rent map lives in EconomySystem const. Don't add new autoloads — ShiftSystem/EconomySystem are plain Nodes in Main.tscn. The user's standing instruction: build ALL milestones (M3→M8 per docs/DESIGN.md roadmap), test headless each, commit+push each, infer answers from the design doc, don't stop.

## After M3: M4 social/perception → M5 confrontation/crime → M6 housing → M7 body/family/aging → M8 living town (see docs/DESIGN.md Part 5 roadmap and task list).
