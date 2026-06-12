extends Node
## M3 smoke test — run headless:
##   godot --headless res://scenes/dev/M3SmokeTest.tscn
## Exercises the survival economy: shifts & paychecks, promotion offers,
## Monday rent & eviction, Big Mickey's interest, the ID quest's day-math,
## the body tick's starvation death, and a save round trip of every new field.

var failures: int = 0
var _died_cause: String = ""


func _ready() -> void:
	# A town must exist so doors register their positions.
	var town: Node2D = load("res://scenes/world/Town.tscn").instantiate()
	add_child(town)
	add_child(ShiftSystem.new())
	add_child(EconomySystem.new())
	EventBus.player_died.connect(func(cause: String) -> void: _died_cause = cause)

	_test_consume_item()
	_test_shift_pay()
	_test_work_spot()
	_test_promotion()
	_test_rent_and_eviction()
	_test_mickey()
	_test_id_quest()
	_test_paths()
	_test_starvation()
	_test_save_roundtrip()
	_test_next_life()
	print("M3 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _new_world() -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_world(sheet)
	return sheet


func _fresh_sheet(origin_id: String) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = origin_id
	WorldState.player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	return sheet


func _test_consume_item() -> void:
	print("[Items: consumption + calories]")
	var sheet := _new_world()
	sheet.needs.values["hunger"] = 50.0
	sheet.inventory = ["instant_noodles"]
	var ok := sheet.consume_item("instant_noodles")
	_check(ok, "consume_item succeeds")
	_check(is_equal_approx(sheet.needs.get_value("hunger"), 72.0), "noodles restore 22 hunger")
	_check(int(sheet.flags.get("calories_today", 0)) == 550, "calories logged (22*25=550)")
	_check(sheet.inventory.is_empty(), "item removed from inventory")
	_check(not sheet.consume_item("instant_noodles"), "can't eat what you don't have")


func _test_shift_pay() -> void:
	print("[ShiftSystem: paycheck math]")
	var sheet := WorldState.player_sheet
	sheet.job_id = "dishwasher"
	var job := ContentDB.get_job("dishwasher")
	var cash0 := sheet.cash_cents
	EventBus.shift_finished.emit(job, 0)
	_check(sheet.cash_cents == cash0 + 5400, "on-time shift pays $54")
	_check(sheet.shifts_worked == 1, "shift counted")
	_check(is_equal_approx(float(sheet.skills.get("cooking", 0.0)), 4.4),
			"cooking XP gained (4.0 * 1.1 hardworking)")
	EventBus.shift_finished.emit(job, 40)
	_check(sheet.cash_cents == cash0 + 5400 + 4050, "40 min late docks 25%% ($40.50)")


func _test_work_spot() -> void:
	print("[WorkSpot: the time-skip work loop]")
	var sheet := WorldState.player_sheet
	sheet.job_id = "dishwasher"
	var spot := WorkSpot.new()
	spot.workplace_id = "loc_diner"
	add_child(spot)
	# Day 14 is a Monday (14 % 7 == 0); dishwasher shift is 16:00-22:00.
	GameClock.total_minutes = 14 * GameClock.MINUTES_PER_DAY + 16 * 60 + 30
	var cash0 := sheet.cash_cents
	var shifts0 := sheet.shifts_worked
	spot.interact(null)
	_check(GameClock.hour == 22, "shift fast-forwards to clock-out (22:00)")
	_check(sheet.cash_cents == cash0 + 5400, "30 min late is within grace — full pay")
	_check(sheet.shifts_worked == shifts0 + 1, "shift counted via work spot")
	spot.queue_free()


func _test_promotion() -> void:
	print("[ShiftSystem: promotion offer]")
	var sheet := WorldState.player_sheet
	sheet.job_id = "dishwasher"
	var job := ContentDB.get_job("dishwasher")
	sheet.skills["cooking"] = 100.0
	sheet.shifts_worked = 9
	EventBus.shift_finished.emit(job, 0)
	_check(sheet.shifts_worked == 10, "10th shift worked")
	_check(sheet.flags.get("promo_offered_line_cook", false),
			"promotion to line cook offered (shifts + skill met)")


func _test_rent_and_eviction() -> void:
	print("[EconomySystem: Monday rent]")
	var sheet := WorldState.player_sheet
	sheet.housing_id = "bricks_unit"
	sheet.rent_strikes = 0
	sheet.cash_cents = 20000
	EventBus.day_passed.emit(7) # Monday
	_check(sheet.cash_cents == 11000, "bricks rent ($90) deducted on Monday")
	_check(sheet.rent_strikes == 0, "no strike when paid")
	sheet.cash_cents = 0
	EventBus.day_passed.emit(14)
	_check(sheet.rent_strikes == 1, "broke Monday = strike 1")
	EventBus.day_passed.emit(21)
	_check(sheet.rent_strikes == 2, "strike 2")
	EventBus.day_passed.emit(28)
	_check(sheet.housing_id == "", "strike 3 = locked out")
	_check(sheet.rent_strikes == 0, "strikes reset after eviction")
	# Prepaid weeks (the exec's head start) cover rent without cash.
	sheet.housing_id = "bricks_unit"
	sheet.flags["rent_prepaid_weeks"] = 2
	sheet.cash_cents = 5000
	EventBus.day_passed.emit(35)
	_check(sheet.cash_cents == 5000, "prepaid week covers rent")
	_check(int(sheet.flags["rent_prepaid_weeks"]) == 1, "prepaid weeks count down")
	sheet.housing_id = ""


func _test_mickey() -> void:
	print("[EconomySystem: Big Mickey]")
	var sheet := WorldState.player_sheet
	sheet.mickey_debt_cents = 100000
	EventBus.day_passed.emit(42) # Monday
	_check(sheet.mickey_debt_cents == 120000, "20%% weekly interest compounds")
	sheet.needs.values["energy"] = 100.0
	sheet.mickey_debt_cents = 200000
	EventBus.day_passed.emit(49)
	_check(sheet.mickey_debt_cents == 240000, "interest on big debt")
	_check(is_equal_approx(sheet.needs.get_value("energy"), 60.0),
			"debt > $1500 = a beating (energy -40)")
	sheet.mickey_debt_cents = 0


func _test_id_quest() -> void:
	print("[RecordsDesk: the ID quest day-math]")
	var sheet := _fresh_sheet("rock_bottom")
	_check(not sheet.flags.get("has_id", true), "no_papers origin starts without ID")
	sheet.cash_cents = 4000
	var desk := RecordsDesk.new()
	add_child(desk)
	GameClock.total_minutes = 10 * GameClock.MINUTES_PER_DAY + 9 * 60 # day 10, 9 AM
	desk.interact(null)
	_check(sheet.cash_cents == 0, "$40 fee paid")
	_check(int(sheet.flags.get("id_ready_day", -1)) == 12, "ready in 2 days (day 12)")
	desk.interact(null)
	_check(not sheet.flags.get("has_id", false), "still processing before ready day")
	GameClock.skip_minutes(2 * GameClock.MINUTES_PER_DAY)
	desk.interact(null)
	_check(sheet.flags.get("has_id", false), "ID issued on/after ready day")
	desk.queue_free()


func _test_paths() -> void:
	print("[LifePaths: Getting Off the Street]")
	var sheet := WorldState.player_sheet # rock_bottom, now with ID
	var street := _find_path(LifePaths.evaluate(sheet), "Getting Off the Street")
	_check(not street.is_empty(), "no_papers origin has the path")
	var all_done := true
	for step in street.steps:
		if not step.done:
			all_done = false
	_check(all_done, "path fully complete after ID quest")

	var broke := _fresh_sheet("rock_bottom")
	broke.cash_cents = 0
	var fresh := _find_path(LifePaths.evaluate(broke), "Getting Off the Street")
	_check(not fresh.steps[0].done and fresh.steps[0].current,
			"fresh tweaker's current step is scraping up the fee")
	var none := _fresh_sheet("off_the_bus")
	_check(_find_path(LifePaths.evaluate(none), "Getting Off the Street").is_empty(),
			"papered origins see no ID path")
	var first_week := _find_path(LifePaths.evaluate(none), "First Week")
	_check(not first_week.is_empty() and first_week.steps[0].current,
			"fresh papered origin starts First Week on getting hired")
	none.job_id = "dishwasher"
	first_week = _find_path(LifePaths.evaluate(none), "First Week")
	_check(first_week.steps[1].current and "Dishwasher" in str(first_week.steps[1].label),
			"First Week points hired players to their first shift")
	none.shifts_worked = 1
	first_week = _find_path(LifePaths.evaluate(none), "First Week")
	_check(not first_week.steps[1].current,
			"First Week first-shift blocker clears after working")


func _find_path(paths: Array, name_part: String) -> Dictionary:
	for p in paths:
		if name_part in str(p.name):
			return p
	return {}


func _test_starvation() -> void:
	print("[Body tick: starvation death]")
	var sheet := _fresh_sheet("off_the_bus")
	sheet.weight_kg = 45.2
	sheet.needs.values["hunger"] = 0.0
	_died_cause = ""
	EventBus.day_passed.emit(8) # not a Monday; pure body tick
	_check(sheet.weight_kg < 45.2, "starving burns weight")
	_check(_died_cause == "starvation", "player_died(starvation) emitted under 45kg")
	_check(not sheet.alive, "death written to the sheet")
	var w := sheet.weight_kg
	EventBus.day_passed.emit(9)
	_check(is_equal_approx(sheet.weight_kg, w), "dead bodies stop ticking")


func _test_save_roundtrip() -> void:
	print("[Save round trip: all new M3 fields]")
	var sheet := _fresh_sheet("off_the_bus")
	sheet.dirty_cents = 1234
	sheet.bank_cents = 5678
	sheet.mickey_debt_cents = 9999
	sheet.inventory = ["meth", "instant_noodles", "instant_noodles"]
	sheet.job_id = "dishwasher"
	sheet.shifts_worked = 7
	sheet.housing_id = "bricks_unit"
	sheet.rent_strikes = 2
	sheet.weight_kg = 81.5
	sheet.lives_lived = 3
	sheet.flags["has_id"] = true
	sheet.flags["calories_today"] = 500
	SaveManager.set_in_game(true)
	SaveManager.save_game()
	WorldState.player_sheet = null
	var npc_count := WorldState.npcs.size()
	WorldState.npcs.clear()
	WorldState.world_exists = false
	var ok := SaveManager.load_game()
	_check(ok, "load_game succeeds")
	var s := WorldState.player_sheet
	_check(s.dirty_cents == 1234 and s.bank_cents == 5678 and s.mickey_debt_cents == 9999,
			"money trio survives (dirty/bank/debt)")
	_check(s.inventory == ["meth", "instant_noodles", "instant_noodles"], "inventory survives")
	_check(s.job_id == "dishwasher" and s.shifts_worked == 7, "job + shifts survive")
	_check(s.housing_id == "bricks_unit" and s.rent_strikes == 2, "housing + strikes survive")
	_check(is_equal_approx(s.weight_kg, 81.5), "weight survives")
	_check(s.lives_lived == 3 and s.alive, "lives/alive survive")
	_check(s.flags.get("has_id", false) and int(s.flags.get("calories_today", 0)) == 500,
			"flags survive")
	_check(WorldState.npcs.size() == npc_count, "population survives")
	_check(WorldState.world_exists, "world_exists survives")
	SaveManager.set_in_game(false)


func _test_next_life() -> void:
	print("[Persistent world: the next life]")
	var npc_count := WorldState.npcs.size()
	WorldState.player_sheet.alive = false
	var prev_lives := WorldState.player_sheet.lives_lived
	var next := CharacterSheet.new()
	next.char_name = "The Next One"
	next.origin_id = "rock_bottom"
	WorldState.start_life(next)
	_check(WorldState.player_sheet == next, "new sheet installed")
	_check(next.lives_lived == prev_lives + 1, "lives_lived increments (%d)" % next.lives_lived)
	_check(WorldState.npcs.size() == npc_count, "the town did NOT reset")
	_check(WorldState.world_exists, "world persists across lives")
