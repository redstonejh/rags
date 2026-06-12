extends Node
## Guardrail for the DESIGN.md baseline: a dishwasher week should be
## survivable, but not comfortable.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/EconomyTelemetrySmokeTest.tscn

const WORK_DAYS := 5
const DAILY_FOOD_ID := "deli_sandwich"
const MIN_WEEKLY_MARGIN_CENTS := 5000
const MAX_WEEKLY_MARGIN_CENTS := 16000

var failures := 0


func _ready() -> void:
	_setup_world()
	await _test_dishwasher_week()
	print("Economy telemetry smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Budget Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 40000
	sheet.housing_id = "bricks_unit"
	sheet.flags["has_id"] = true
	sheet.job_id = "dishwasher"
	WorldState.new_world(sheet)
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 7 * 60
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	SaveManager.set_in_game(false)


func _test_dishwasher_week() -> void:
	print("[Dishwasher week telemetry]")
	var shift_system := ShiftSystem.new()
	var economy_system := EconomySystem.new()
	add_child(shift_system)
	add_child(economy_system)
	await get_tree().process_frame

	var sheet := WorldState.player_sheet
	var job := ContentDB.get_job("dishwasher")
	var food := ContentDB.get_item(DAILY_FOOD_ID)
	_check(job != null and job.wage_cents_per_shift == 5400,
			"dishwasher wage matches the design anchor")
	_check(food != null and food.value_cents > 0,
			"daily food item is priced")
	if job == null or food == null:
		return

	var start_cash := sheet.cash_cents
	for _i in WORK_DAYS:
		EventBus.shift_finished.emit(job, 0)
		_buy_and_eat(food.id)

	GameClock.total_minutes = 7 * GameClock.MINUTES_PER_DAY
	EventBus.day_passed.emit(GameClock.day)
	await get_tree().process_frame

	var margin := sheet.cash_cents - start_cash
	_check(sheet.shifts_worked == WORK_DAYS,
			"five dishwasher shifts complete")
	_check(sheet.cash_cents == start_cash \
			+ WORK_DAYS * job.wage_cents_per_shift \
			- WORK_DAYS * food.value_cents \
			- ContentDB.get_housing("bricks_unit").weekly_rent_cents,
			"weekly cash math includes wages, food, and rent")
	_check(int(sheet.flags.get("clean_rent_weeks", 0)) == 1,
			"rent payment records one clean week")
	_check(margin >= MIN_WEEKLY_MARGIN_CENTS,
			"dishwasher week leaves enough margin to survive")
	_check(margin <= MAX_WEEKLY_MARGIN_CENTS,
			"dishwasher week stays financially tight")


func _buy_and_eat(item_id: String) -> void:
	var sheet := WorldState.player_sheet
	var item := ContentDB.get_item(item_id)
	if sheet == null or item == null:
		return
	sheet.add_cash(-item.value_cents)
	sheet.inventory.append(item_id)
	sheet.consume_item(item_id)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
