extends Node
## M2 smoke test — run headless:
##   godot --headless res://scenes/dev/M2SmokeTest.tscn
## Simulates full days of the abstract NPC sim and checks that the town
## behaves like a town: workers go to work, sleepers sleep, travel resolves,
## saves round-trip the whole population.

var failures: int = 0
var _save_guard := SaveSlotGuard.new()
var _town: Node = null


func _ready() -> void:
	_save_guard.backup()
	# A town must exist so doors register their positions.
	_town = load("res://scenes/world/Town.tscn").instantiate()
	add_child(_town)

	_test_world_gen()
	_test_schedule_day()
	_test_save_roundtrip()
	_test_sim_rng_save_roundtrip()
	_test_embodiment_sets()
	SaveManager.set_in_game(false)
	_save_guard.restore()
	print("M2 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _new_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_game(sheet)


func _test_world_gen() -> void:
	print("[WorldGen]")
	_new_world()
	var n := WorldState.npcs.size()
	_check(n >= 150 and n <= 250, "population in range (%d)" % n)
	var bad := 0
	var subversions := 0
	var names := {}
	for npc in WorldState.npcs.values():
		if npc.archetype() == null or not Locations.defs.has(npc.home_id):
			bad += 1
		names[npc.display_name] = true
		if npc.is_subversion:
			subversions += 1
		for s in CharacterSheet.STAT_IDS:
			if not npc.stats.has(s):
				bad += 1
	_check(bad == 0, "all NPCs have valid archetype/home/stats")
	_check(names.size() == n, "generated NPC display names are unique")
	_check(subversions > 5 and subversions < n / 4,
			"subversion rate sane (%d/%d)" % [subversions, n])
	var seeded_a := WorldGen.generate(24680)
	var seeded_b := WorldGen.generate(24680)
	_check(_population_signature(seeded_a) == _population_signature(seeded_b),
			"world generation is deterministic for a fixed seed")
	_check(_exterior_anchor_signature(13579) == _exterior_anchor_signature(13579),
			"exterior wander anchors are deterministic for a fixed seed")
	var doors := Locations.door_positions.size()
	_check(doors >= 9, "door registry populated (%d doors)" % doors)


## Drive the clock through 2 full days and sample the town at key hours.
func _test_schedule_day() -> void:
	print("[Schedules: simulating 2 days]")
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY # day 1, 00:00
	var samples := {}
	for _m in range(GameClock.MINUTES_PER_DAY * 2):
		GameClock.total_minutes += 1
		EventBus.minute_passed.emit(GameClock.total_minutes)
		var hour := GameClock.hour
		var minute := GameClock.minute
		if minute == 0 and hour in [3, 10, 19]:
			samples["%d:%d" % [GameClock.day, hour]] = _census()

	var night: Dictionary = samples.get("2:3", {})
	var midmorning: Dictionary = samples.get("2:10", {})
	var evening: Dictionary = samples.get("2:19", {})

	var total := WorldState.npcs.size()
	var asleep_at_3: int = night.get("sleeping", 0)
	_check(asleep_at_3 > total * 0.5,
			"most of town asleep at 3 AM (%d/%d)" % [asleep_at_3, total])
	var working_at_10: int = midmorning.get("working", 0)
	_check(working_at_10 >= 60,
			"workforce at work at 10 AM (%d)" % working_at_10)
	var diner_at_10: int = midmorning.get("@loc_diner", 0)
	_check(diner_at_10 >= 8, "diner staffed at 10 AM (%d present)" % diner_at_10)
	var bar_at_19: int = evening.get("@loc_bar", 0)
	_check(bar_at_19 >= 10, "bar busy at 7 PM (%d present)" % bar_at_19)
	var stuck := 0
	for npc in WorldState.npcs.values():
		if npc.traveling and GameClock.total_minutes - npc.travel_depart_min > 120:
			stuck += 1
	_check(stuck == 0, "no NPC stuck traveling >2h (%d)" % stuck)


func _census() -> Dictionary:
	var c := {}
	for npc in WorldState.npcs.values():
		c[npc.current_activity] = c.get(npc.current_activity, 0) + 1
		var loc: String = "@" + npc.current_location_id
		c[loc] = c.get(loc, 0) + 1
	return c


func _population_signature(population: Dictionary) -> String:
	var ids := population.keys()
	ids.sort()
	var rows := []
	for id in ids:
		var npc: NPCRecord = population[id]
		rows.append([
			npc.id,
			npc.display_name,
			npc.archetype_id,
			npc.appearance_tags,
			npc.is_subversion,
			npc.stats,
			npc.personality,
			npc.flags,
			npc.home_id,
			npc.workplace_id,
			npc.schedule_offset,
			npc.money_cents,
			npc.age_years,
			npc.energy,
			npc.hunger,
		])
	return JSON.stringify(rows)


func _exterior_anchor_signature(seed_value: int) -> String:
	if _town == null or not _town.has_method("random_exterior_point"):
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := []
	for _i in 20:
		var point: Vector2 = _town.random_exterior_point(rng)
		points.append([point.x, point.y])
	return JSON.stringify(points)


func _test_save_roundtrip() -> void:
	print("[Save round trip with population]")
	var before := WorldState.npcs.size()
	var probe: NPCRecord = WorldState.npcs.values()[42]
	var probe_id := probe.id
	var probe_loc := probe.current_location_id
	var probe_stats := probe.stats.duplicate()
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success")
	WorldState.npcs.clear()
	WorldState.player_sheet = null
	var ok := SaveManager.load_game()
	_check(ok, "load_game succeeds")
	_check(WorldState.npcs.size() == before, "population survives (%d)" % WorldState.npcs.size())
	var p: NPCRecord = WorldState.npcs.get(probe_id)
	_check(p != null and p.current_location_id == probe_loc and p.stats == probe_stats,
			"spot-checked NPC record identical after round trip")
	SaveManager.set_in_game(false)


func _test_sim_rng_save_roundtrip() -> void:
	print("[Save round trip with sim RNG]")
	_new_world()
	SimEngine.spawn_host = _town
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 9 * 60
	var npc: NPCRecord = WorldState.npcs.values()[0]
	npc.current_location_id = "loc_diner"
	npc.traveling = false
	var first_expected := _next_exterior_anchor(WorldState.sim_rng_state)
	SimEngine.call("_start_travel", npc, "exterior", GameClock.total_minutes)
	_check(npc.travel_to_pos.distance_to(first_expected) < 0.01,
			"first exterior travel uses saved sim RNG state")
	var state_after_first := WorldState.sim_rng_state
	var expected_after_reload := _next_exterior_anchor(state_after_first)
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success with sim RNG state")
	WorldState.npcs.clear()
	WorldState.player_sheet = null
	WorldState.sim_rng_state = 0
	_check(SaveManager.load_game(), "load_game restores sim RNG state")
	var loaded_npc: NPCRecord = WorldState.npcs.values()[1]
	loaded_npc.current_location_id = "loc_diner"
	loaded_npc.traveling = false
	SimEngine.call("_start_travel", loaded_npc, "exterior", GameClock.total_minutes)
	_check(loaded_npc.travel_to_pos.distance_to(expected_after_reload) < 0.01,
			"loaded sim RNG continues the exterior travel sequence")
	SaveManager.set_in_game(false)


func _next_exterior_anchor(state: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldState.sim_rng_seed
	rng.state = state
	return _town.random_exterior_point(rng)


func _test_embodiment_sets() -> void:
	print("[Embodiment selection]")
	# Player standing in the diner at noon: staff should be selectable.
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 12 * 60
	for _m in range(30): # settle the sim at noon
		GameClock.total_minutes += 1
		EventBus.minute_passed.emit(GameClock.total_minutes)
	WorldState.player_location_id = "loc_diner"
	var picks := SimEngine.compute_desired_embodied()
	_check(picks.size() >= 3, "diner at noon selects %d NPCs to embody" % picks.size())
	_check(picks.size() <= SimEngine.MAX_EMBODIED, "embodiment respects cap")
	var all_here := true
	for npc in picks:
		if npc.current_location_id != "loc_diner":
			all_here = false
	_check(all_here, "every selected NPC is actually at the diner")
	WorldState.player_location_id = "exterior"
