extends Node
## Drives a real-scene dishwasher week through Main, shop UI, WorkSpot,
## CharacterSheet food use, sleep, and Monday rent.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/DishwasherWeekSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const WORK_DAYS := 5
const MEAL_ID := "deli_sandwich"
const START_CASH_CENTS := 40000

var failures := 0
var _main: Node = null
var _player: Node = null


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	await _run_week()
	_finish()


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Week Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = START_CASH_CENTS
	sheet.housing_id = "bricks_unit"
	sheet.job_id = "dishwasher"
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	GameClock.total_minutes = 7 * 60 # Monday, 7:00 AM.
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	SaveManager.set_in_game(false)
	seed(11)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player")
	_check(_player != null, "main scene has a player")


func _run_week() -> void:
	var sheet := WorldState.player_sheet
	var job := ContentDB.get_job("dishwasher")
	var meal := ContentDB.get_item(MEAL_ID)
	var rent := ContentDB.get_housing("bricks_unit").weekly_rent_cents
	_check(job != null and meal != null, "weekly loop has job and meal definitions")
	if job == null or meal == null:
		return

	for day_index in WORK_DAYS:
		await _buy_and_eat_meal("breakfast day %d" % (day_index + 1))
		_skip_to_shift_window(job)
		await _work_shift(day_index + 1)
		await _buy_and_eat_meal("dinner day %d" % (day_index + 1))
		await _sleep_home(day_index + 1)

	_check(sheet.shifts_worked == WORK_DAYS, "real week completes five dishwasher shifts")
	_check(sheet.cash_cents > 0, "player keeps positive cash before Monday rent")
	var pre_rent_cash := sheet.cash_cents
	_skip_to_next_monday_rent()
	await get_tree().process_frame
	_check(int(sheet.flags.get("clean_rent_weeks", 0)) >= 1,
			"Monday rent is paid after the real work week")
	_check(sheet.cash_cents == pre_rent_cash - rent,
			"Monday rent deducts the expected amount")
	_check(sheet.cash_cents > START_CASH_CENTS,
			"week leaves a modest positive cash margin")
	_check(sheet.cash_cents < START_CASH_CENTS + 16000,
			"week remains financially tight")
	_check(sheet.alive and sheet.weight_kg > 70.0,
			"player survives the playable dishwasher week without starvation spiral")


func _buy_and_eat_meal(label: String) -> void:
	EventBus.travel_requested.emit("loc_store")
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(WorldState.player_location_id == "loc_store",
			"%s: player reaches the store" % label)
	var counter := _find_descendant_of_type(_main.get("current_world"), ShopCounter) as ShopCounter
	_check(counter != null, "%s: store counter exists" % label)
	if counter == null:
		return
	_player.set("global_position", counter.global_position)
	await get_tree().physics_frame
	_player.call("_physics_process", 0.0)
	_player.call("_unhandled_input", _action("interact"))
	await get_tree().process_frame
	var shop: CanvasLayer = _main.get_node("Shop")
	var buy_button := _find_named_descendant(shop, "Buy_%s" % MEAL_ID) as Button
	_check(shop.visible and buy_button != null, "%s: shop exposes meal purchase" % label)
	if buy_button == null:
		return
	var sheet := WorldState.player_sheet
	var cash_before := sheet.cash_cents
	var count_before := sheet.count_item(MEAL_ID)
	buy_button.pressed.emit()
	await get_tree().process_frame
	_check(sheet.cash_cents < cash_before and sheet.count_item(MEAL_ID) == count_before + 1,
			"%s: buying meal spends cash and adds inventory" % label)
	shop.call("_close")
	await get_tree().process_frame
	var hunger_before := sheet.needs.get_value("hunger")
	var calories_before := int(sheet.flags.get("calories_today", 0))
	var eaten := sheet.consume_item(MEAL_ID)
	_check(eaten and sheet.count_item(MEAL_ID) == count_before,
			"%s: meal is consumed from inventory" % label)
	_check(sheet.needs.get_value("hunger") >= hunger_before,
			"%s: meal does not reduce hunger" % label)
	_check(int(sheet.flags.get("calories_today", 0)) > calories_before,
			"%s: meal records calories" % label)


func _skip_to_shift_window(job: JobDef) -> void:
	var target := GameClock.day * GameClock.MINUTES_PER_DAY + job.shift_start_hour * 60 - 30
	GameClock.skip_minutes(maxi(0, target - GameClock.total_minutes))


func _work_shift(day_number: int) -> void:
	EventBus.travel_requested.emit("loc_diner")
	await get_tree().process_frame
	await get_tree().physics_frame
	var work_spot := _find_descendant_of_type(_main.get("current_world"), WorkSpot) as WorkSpot
	_check(work_spot != null and work_spot.workplace_id == "loc_diner",
			"day %d: diner work spot exists" % day_number)
	if work_spot == null:
		return
	var cash_before := WorldState.player_sheet.cash_cents
	_player.set("global_position", work_spot.global_position)
	await get_tree().physics_frame
	_player.call("_physics_process", 0.0)
	_player.call("_unhandled_input", _action("interact"))
	await get_tree().process_frame
	await _resolve_optional_dilemma()
	_check(GameClock.hour == 22 and GameClock.minute == 0,
			"day %d: shift ends at 10 PM" % day_number)
	_check(WorldState.player_sheet.cash_cents > cash_before,
			"day %d: shift pays through the real work spot" % day_number)


func _resolve_optional_dilemma() -> void:
	var dilemma: CanvasLayer = _main.get_node("Dilemma")
	if not dilemma.visible:
		_check(not GameClock.paused, "shift returns control without a dilemma")
		return
	var choice := _find_enabled_button(dilemma)
	_check(choice != null, "post-shift dilemma has a choice")
	if choice == null:
		return
	choice.pressed.emit()
	await get_tree().process_frame
	_check(not dilemma.visible and not GameClock.paused, "post-shift dilemma closes cleanly")


func _sleep_home(day_number: int) -> void:
	EventBus.travel_requested.emit("loc_bricks")
	await get_tree().process_frame
	await get_tree().physics_frame
	var bed := _find_amenity("bed")
	_check(bed != null, "day %d: home bed exists" % day_number)
	if bed == null:
		return
	_player.set("global_position", bed.global_position)
	await get_tree().physics_frame
	_player.call("_physics_process", 0.0)
	_player.call("_unhandled_input", _action("interact"))
	await get_tree().process_frame
	_check(GameClock.hour == 7 and GameClock.minute == 0,
			"day %d: sleep reaches 7 AM" % day_number)
	_check(not GameClock.paused and GameClock.pause_lock_count() == 0,
			"day %d: sleep leaves no pause locks" % day_number)


func _skip_to_next_monday_rent() -> void:
	var current_day := GameClock.day
	var days_until_monday := (7 - (current_day % 7)) % 7
	if days_until_monday == 0:
		days_until_monday = 7
	var target_day := current_day + days_until_monday
	var target := target_day * GameClock.MINUTES_PER_DAY + 1
	GameClock.skip_minutes(maxi(0, target - GameClock.total_minutes))


func _find_descendant_of_type(node: Node, type) -> Node:
	if node == null:
		return null
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var found := _find_descendant_of_type(child, type)
		if found != null:
			return found
	return null


func _find_named_descendant(node: Node, node_name: String) -> Node:
	if node == null:
		return null
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_named_descendant(child, node_name)
		if found != null:
			return found
	return null


func _find_enabled_button(node: Node) -> Button:
	if node is Button and not node.disabled:
		return node
	for child in node.get_children():
		var found := _find_enabled_button(child)
		if found != null:
			return found
	return null


func _find_amenity(kind: String) -> Amenity:
	return _find_amenity_in(_main.get("current_world"), kind)


func _find_amenity_in(node: Node, kind: String) -> Amenity:
	if node == null:
		return null
	if node is Amenity and str(node.kind) == kind:
		return node
	for child in node.get_children():
		var found := _find_amenity_in(child, kind)
		if found != null:
			return found
	return null


func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _finish() -> void:
	SaveManager.set_in_game(false)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	print("Dishwasher week smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
