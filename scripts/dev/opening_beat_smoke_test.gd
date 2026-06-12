extends Node
## Exercises origin start markers and the first-day opening beat through Main.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/OpeningBeatSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures := 0
var _main: Node = null
var _toasts: Array[String] = []


func _ready() -> void:
	await _run_origin_start_case("off_the_bus", "Arrival Walker",
			"loc_bus_stop", "Small-Town Transplant", "bus stop", "BusStopSprite")
	await _run_origin_start_case("rock_bottom", "Alley Starter",
			"loc_gas_station_rear", "Tweaker", "behind the gas station", "StreetCampSprite")
	print("Opening beat smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _run_origin_start_case(origin_id: String, char_name: String, expected_marker: String,
		origin_toast_text: String, start_toast_text: String, expected_prop_name: String) -> void:
	await _teardown_main()
	_setup_world(origin_id, char_name)
	await _instantiate_main()
	_test_origin_start_and_opening_beat(expected_marker, origin_toast_text,
			start_toast_text, expected_prop_name)


func _setup_world(origin_id: String, char_name: String) -> void:
	_toasts.clear()
	var sheet := CharacterSheet.new()
	sheet.char_name = char_name
	sheet.origin_id = origin_id
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	if not EventBus.toast.is_connected(_on_toast):
		EventBus.toast.connect(_on_toast)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _test_origin_start_and_opening_beat(expected_marker: String, origin_toast_text: String,
		start_toast_text: String, expected_prop_name: String) -> void:
	var player: Node2D = _main.get_node("Player")
	var start_marker := str(WorldState.player_sheet.flags.get("start_location_id", ""))
	var expected := Locations.door_pos(expected_marker)
	_check(start_marker == expected_marker, "%s start marker is stored on the sheet" % expected_marker)
	_check(player.global_position.distance_to(expected) <= 1.0,
			"%s first-life exterior spawn uses the origin start marker" % expected_marker)
	_check(expected.x >= 160.0,
			"%s origin start marker is clear of the HUD at the west camera limit" % expected_marker)
	_check(WorldState.player_location_id == "exterior",
			"%s exterior start marker preserves simulation location" % expected_marker)
	_check(int(WorldState.player_sheet.flags.get("opening_seen_life", 0)) \
			== WorldState.player_sheet.lives_lived,
			"%s opening beat is recorded for this life" % expected_marker)
	_check(_toasts.any(func(t: String) -> bool:
			return origin_toast_text in t and start_toast_text in t),
			"%s opening beat names the origin and start place" % expected_marker)
	_check(_current_world_has_node(expected_prop_name),
			"%s opening prop exists near the start marker" % expected_marker)


func _current_world_has_node(node_name: String) -> bool:
	if _main == null:
		return false
	var world_root := _main.get_node_or_null("WorldRoot")
	if world_root == null or world_root.get_child_count() == 0:
		return false
	return _find_named_descendant(world_root.get_child(0), node_name) != null


func _find_named_descendant(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_named_descendant(child, node_name)
		if found != null:
			return found
	return null


func _teardown_main() -> void:
	if _main == null:
		return
	remove_child(_main)
	_main.queue_free()
	_main = null
	await get_tree().process_frame


func _on_toast(message: String) -> void:
	_toasts.append(message)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
