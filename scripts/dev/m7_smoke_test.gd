extends Node
## M7 smoke test — run headless:
##   godot --headless res://scenes/dev/M7SmokeTest.tscn
## Exercises the body and the life: the 8-substance catalog (tolerance,
## addiction, craving, the confidence lie), Recovery + Education paths,
## wounds that heal wrong, teeth and surgery, aging to death, marriage ->
## pregnancy -> the baby gauntlet -> kid traits, heirs, obituaries, Walk
## Away, and the save round trip of an entire biography.

var failures: int = 0
var _died_cause: String = ""
var _save_guard := SaveSlotGuard.new()


func _ready() -> void:
	_save_guard.backup()
	var town: Node2D = load("res://scenes/world/Town.tscn").instantiate()
	add_child(town)
	add_child(EconomySystem.new())
	EventBus.player_died.connect(func(cause: String) -> void: _died_cause = cause)

	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_world(sheet)

	_test_catalog()
	_test_substance_use()
	_test_tolerance()
	_test_overdose_robbery()
	_test_recovery()
	_test_wounds()
	_test_teeth_and_surgery()
	_test_lsd()
	_test_education()
	_test_family()
	_test_body_rng_save_roundtrip()
	_test_aging_and_death()
	_test_walk_away()
	_test_save_roundtrip()
	SaveManager.set_in_game(false)
	_save_guard.restore()
	print("M7 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _count_money_updates(action: Callable) -> int:
	var events := {"count": 0}
	var signal_handler := func(_cash_cents: int) -> void:
		events["count"] = int(events.count) + 1
	EventBus.money_changed.connect(signal_handler)
	action.call()
	EventBus.money_changed.disconnect(signal_handler)
	return int(events.count)


func _fresh_sheet() -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	return sheet


func _test_catalog() -> void:
	print("[Substances: the honest catalog]")
	_check(ContentDB.substances.size() >= 8, "8 substances loaded (%d)" % ContentDB.substances.size())
	var xanax := ContentDB.get_substance("xanax")
	_check(xanax != null and xanax.deadly_with_alcohol, "the game tracks xanax + alcohol")
	_check(ContentDB.get_substance("meth").tooth_risk > 0.0, "meth costs teeth")


func _test_substance_use() -> void:
	print("[A dose: effects, flags, the ledger]")
	var sheet := _fresh_sheet()
	sheet.needs.values["fun"] = 40.0
	var text := Body.use_substance(sheet, "weed")
	_check(text != "", "weed narrates")
	_check(sheet.needs.get_value("fun") > 40.0, "the high is real")
	var state := Body.substance_state(sheet, "weed")
	_check(float(state.addiction) > 0.0 and float(state.tolerance) > 0.0,
			"addiction and tolerance both tick up")
	_check(int(state.last_use_day) == GameClock.day, "the ledger knows the date")
	Body.use_substance(sheet, "meth")
	_check(sheet.needs.values.has("craving"), "meth installs the craving bar")
	_check(int(sheet.flags.get("drunk_minutes", 0)) > 0, "fake confidence while high")


func _test_tolerance() -> void:
	print("[Tolerance: the high shrinks]")
	var sheet := _fresh_sheet()
	sheet.needs.values["fun"] = 0.0
	Body.use_substance(sheet, "weed")
	var first_hit := sheet.needs.get_value("fun")
	var state := Body.substance_state(sheet, "weed")
	state.tolerance = 1.0
	sheet.needs.values["fun"] = 0.0
	Body.use_substance(sheet, "weed")
	_check(sheet.needs.get_value("fun") < first_hit,
			"maxed tolerance blunts the hit (%.0f -> %.0f)" % [first_hit, sheet.needs.get_value("fun")])


func _test_overdose_robbery() -> void:
	print("[Collapse: wake up robbed]")
	var sheet := _fresh_sheet()
	sheet.cash_cents = 10000
	var money_events := _count_money_updates(func() -> void:
		Body._overdose(sheet))
	_check(sheet.cash_cents == 5000, "collapse robbery takes half your cash")
	_check(money_events > 0, "collapse robbery refreshes money UI")


func _test_recovery() -> void:
	print("[Recovery: clean days are the only currency]")
	var sheet := _fresh_sheet()
	var state := Body.substance_state(sheet, "meth")
	state.addiction = 0.5
	state.last_use_day = GameClock.day - 1
	state.clean_days = 0
	Body.daily_tick(sheet)
	_check(int(Body.substance_state(sheet, "meth").clean_days) == 1, "a clean day counts")
	_check(float(Body.substance_state(sheet, "meth").addiction) < 0.5, "addiction fades glacially")
	state.clean_days = 7
	var paths := LifePaths.evaluate(sheet)
	var recovery: Dictionary = {}
	for p in paths:
		if "Recovery" in str(p.name):
			recovery = p
	_check(not recovery.is_empty(), "Recovery path appears for the addicted")
	_check(recovery.steps[2].done and not recovery.steps[3].done,
			"7 days clean: the hard week done, the chip pending")


func _test_wounds() -> void:
	print("[Wounds: heal, or heal wrong]")
	var sheet := _fresh_sheet()
	Body.add_wound(sheet, "fracture")
	_check(sheet.get_stat("DEX") == 7, "open fracture drags DEX (-1)")
	for _d in 14:
		Body.daily_tick(sheet)
	_check(sheet.wounds.is_empty(), "the fracture closed")
	_check(sheet.flags.get("crooked_arm", false), "...wrong. Untreated = permanent")
	_check(sheet.get_stat("DEX") == 7, "the crooked arm is forever (-1 DEX)")
	var patient := _fresh_sheet()
	Body.add_wound(patient, "fracture")
	Body.treat_wounds(patient)
	for _d in 5:
		Body.daily_tick(patient)
	_check(patient.wounds.is_empty() and not patient.flags.get("crooked_arm", false),
			"treated fractures heal clean")


func _test_teeth_and_surgery() -> void:
	print("[Teeth and the surgeon]")
	var sheet := _fresh_sheet()
	var base_cha := sheet.get_stat("CHA")
	sheet.flags["teeth"] = 26
	_check(sheet.get_stat("CHA") == base_cha - 1, "missing teeth cost CHA")
	sheet.flags["dentures"] = true
	_check(sheet.get_stat("CHA") == base_cha, "dentures buy it back")
	sheet.flags["cha_surgery"] = 1
	_check(sheet.get_stat("CHA") == base_cha + 1, "plastic surgery buys CHA with cash")


func _test_lsd() -> void:
	print("[LSD: the perception system resigns]")
	var sheet := _fresh_sheet()
	var npc := NPCRecord.new()
	npc.id = "npc_trip"
	npc.appearance_tags = ["plain"]
	for s in CharacterSheet.STAT_IDS:
		npc.stats[s] = 8
	sheet.flags["lsd_minutes"] = 120
	var line := Perception.read_line(sheet, npc)
	_check(line in Perception._LSD_READS, "reads become poetry (\"%s\")" % line)
	sheet.flags.erase("lsd_minutes")


func _test_education() -> void:
	print("[Education: night school pays off]")
	var sheet := _fresh_sheet()
	sheet.flags["ged_done_day"] = GameClock.day
	Body.daily_tick(sheet)
	_check(sheet.flags.get("ged", false), "GED lands on schedule")
	_check(sheet.skill_level("education") >= 1, "education is a skill now")
	var has_edu_path := false
	for p in LifePaths.evaluate(sheet):
		if str(p.name) == "Education":
			has_edu_path = p.steps[3].done
	_check(has_edu_path, "Education path shows complete")


func _test_family() -> void:
	print("[Family: the whole pipeline]")
	var sheet := _fresh_sheet()
	var beau := NPCRecord.new()
	beau.id = "npc_beau"
	beau.display_name = "Marlene Crick"
	beau.archetype_id = "barfly"
	beau.appearance_tags = ["friendly"]
	for s in CharacterSheet.STAT_IDS:
		beau.stats[s] = 8
	beau.personality = {"bravery": 50, "greed": 50, "civic_duty": 50,
			"kindness": 70, "chattiness": 60, "jealousy": 20}
	beau.relationships["player"] = 75.0
	beau.flags["dating_player"] = true
	WorldState.npcs[beau.id] = beau
	_check("propose" in Social.available_actions(sheet, beau), "propose unlocks at 70+ while dating")
	Social.interact(sheet, beau, "propose", 0.0)
	_check(beau.flags.get("married_to_player", false) and sheet.flags.get("spouse_id", "") == "npc_beau",
			"married at the courthouse")
	Social.interact(sheet, beau, "try_for_baby", 0.1)
	_check(sheet.flags.has("pregnant_due_day"), "two pink lines")
	sheet.flags["pregnant_due_day"] = GameClock.day
	sheet.cash_cents = 50000
	Body.daily_tick(sheet)
	_check(sheet.children.size() == 1, "the baby arrives, furious")
	var energy_before := sheet.needs.get_value("energy")
	var cash_before := sheet.cash_cents
	Body.daily_tick(sheet)
	_check(sheet.needs.get_value("energy") < energy_before, "night feeds wreck energy")
	_check(sheet.cash_cents < cash_before, "daycare costs money")
	# Five years on, the kid becomes somebody — shaped by how you lived.
	sheet.children[0].born_day = GameClock.day - 25
	Body.daily_tick(sheet)
	_check(not sheet.children[0].traits.is_empty(),
			"kid traits written at five (%s)" % str(sheet.children[0].traits))
	# Sixteen years on, they can inherit everything.
	sheet.children[0].born_day = GameClock.day - 80
	_check(Body.heir_candidates(sheet).size() == 1, "grown kid is heir-eligible")
	var obit := Body.obituary(sheet, "testing")
	_check("Test Subject" in obit and "child" in obit, "the obituary tells the story")


func _test_body_rng_save_roundtrip() -> void:
	print("[Save round trip: body RNG]")
	var sheet := _fresh_sheet()
	WorldState.world_seed = 888123
	WorldState.reset_body_rng()
	sheet.flags["pregnant_due_day"] = GameClock.day
	var before_state := WorldState.body_rng_state
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success with body RNG state")
	Body.daily_tick(sheet)
	var expected := _body_signature(sheet, [
		Body.roll_chance(0.2),
		Body.roll_chance(0.1),
	])
	_check(WorldState.body_rng_state != before_state,
			"birth advances saved body RNG state")
	WorldState.player_sheet = null
	WorldState.body_rng_state = 0
	_check(SaveManager.load_game(), "load_game restores body RNG state")
	var loaded := WorldState.player_sheet
	Body.daily_tick(loaded)
	var actual := _body_signature(loaded, [
		Body.roll_chance(0.2),
		Body.roll_chance(0.1),
	])
	_check(actual == expected,
			"loaded body RNG repeats the same birth and public roll results")
	SaveManager.set_in_game(false)


func _body_signature(sheet: CharacterSheet, public_rolls: Array = []) -> String:
	var children := []
	for kid in sheet.children:
		children.append([
			str(kid.get("name", "")),
			int(kid.get("born_day", 0)),
			kid.get("traits", []),
		])
	return JSON.stringify({
		"children": children,
		"flags": {
			"pregnant_due_day": int(sheet.flags.get("pregnant_due_day", -1)),
		},
		"public_rolls": public_rolls,
		"body_rng_state": str(WorldState.body_rng_state),
	})


func _test_aging_and_death() -> void:
	print("[Aging: the schedule everyone keeps]")
	var sheet := _fresh_sheet()
	var age0 := sheet.age_years
	Body.daily_tick(sheet)
	_check(sheet.age_years > age0, "a day ages you (5 days = 1 year)")
	sheet.age_years = 200.0 # methuselah mode: the roll must land fast
	_died_cause = ""
	for _i in 200:
		Body.daily_tick(sheet)
		if not sheet.alive:
			break
	_check(_died_cause == "old age" and not sheet.alive, "old age comes for everyone")
	# NPCs age and the town turns over.
	var elder: NPCRecord = WorldState.npcs.values()[0]
	elder.age_years = 120.0
	for _i in 400:
		Body.age_npcs()
		if not elder.alive:
			break
	_check(not elder.alive, "elder NPCs pass; their jobs open up")


func _test_walk_away() -> void:
	print("[Walking Away: retirement as a flag flip]")
	var sheet := _fresh_sheet()
	sheet.char_name = "Roy Quitter"
	sheet.cash_cents = 11100
	sheet.bank_cents = 22200
	var npc := WorldState.walk_away()
	_check(npc != null and npc.display_name == "Roy Quitter", "the sheet becomes a record")
	_check(npc.money_cents == 33300, "they keep the money you saved")
	_check(not sheet.alive, "the life is over; the person isn't")
	_check(WorldState.npcs.has(npc.id), "your old self is in the town now")
	_check(not WorldState.obituaries.is_empty(), "the archive notes the retirement")


func _test_save_roundtrip() -> void:
	print("[Save round trip: a whole biography]")
	var sheet := _fresh_sheet()
	Body.use_substance(sheet, "weed")
	Body.add_wound(sheet, "cut")
	sheet.age_years = 41.5
	sheet.children = [{"name": "Dot", "born_day": 3, "traits": ["sunny"]}]
	var obit_count := WorldState.obituaries.size()
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success")
	WorldState.player_sheet = null
	WorldState.obituaries = []
	var ok := SaveManager.load_game()
	var s := WorldState.player_sheet
	_check(ok and s != null, "load_game succeeds")
	_check(s.substances.has("weed"), "the habit survives")
	_check(s.wounds.size() == 1 and str(s.wounds[0].kind) == "cut", "the wound survives")
	_check(is_equal_approx(s.age_years, 41.5), "age survives")
	_check(s.children.size() == 1 and str(s.children[0].name) == "Dot", "Dot survives")
	_check(WorldState.obituaries.size() == obit_count, "the Gazette archive survives")
	SaveManager.set_in_game(false)
