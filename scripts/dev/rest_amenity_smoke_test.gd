extends Node
## Exercises real rest interaction through Main, Player input, and Amenity.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/RestAmenitySmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures := 0
var _main: Node = null
var _player: Node = null


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	await _test_bed_sleep_interaction()
	print("Rest amenity smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Rest Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.housing_id = "bricks_unit"
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	sheet.needs.values["energy"] = 20.0
	sheet.needs.values["hunger"] = 100.0
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 23 * 60
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	SaveManager.set_in_game(false)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player")
	_check(_player != null, "main scene has a player")


func _test_bed_sleep_interaction() -> void:
	EventBus.travel_requested.emit("loc_bricks")
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(WorldState.player_location_id == "loc_bricks", "player enters housing interior")
	var bed := _find_amenity("bed")
	_check(bed != null, "owned home bed exists")
	if bed == null:
		return

	var sheet := WorldState.player_sheet
	var energy_before := sheet.needs.get_value("energy")
	var day_before := GameClock.day
	_player.set("global_position", bed.global_position)
	await get_tree().physics_frame
	_player.call("_physics_process", 0.0)
	_player.call("_unhandled_input", _action("interact"))
	await get_tree().process_frame

	_check(GameClock.day == day_before + 1 and GameClock.hour == 7 and GameClock.minute == 0,
			"bed sleep advances to 7 AM tomorrow")
	_check(sheet.needs.get_value("energy") > energy_before,
			"bed sleep restores energy")
	_check(not GameClock.paused and GameClock.pause_lock_count() == 0,
			"bed sleep returns control without pause locks")


func _find_amenity(kind: String) -> Amenity:
	var current_world: Node = _main.get("current_world")
	return _find_amenity_in(current_world, kind)


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


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
