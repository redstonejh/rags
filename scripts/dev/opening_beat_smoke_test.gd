extends Node
## Exercises origin start markers and the first-day opening beat through Main.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/OpeningBeatSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const START_MARKER_PROPS := {
	"loc_bus_stop": "BusStopSprite",
	"loc_gas_station_rear": "StreetCampSprite",
	"loc_decent_apartment": "ApartmentSignSprite",
}

var failures := 0
var _main: Node = null
var _toasts: Array[String] = []


func _ready() -> void:
	var origins := ContentDB.all_origins()
	_check(not origins.is_empty(), "ContentDB has origins to verify")
	for origin: OriginDef in origins:
		var expected_marker := origin.starting_location_id
		_check(expected_marker != "",
				"%s defines a first-life start marker" % origin.id)
		_check(origin.opening_line.strip_edges() != "",
				"%s defines a first-life opening line" % origin.id)
		if expected_marker == "":
			continue
		var expected_prop_name := str(START_MARKER_PROPS.get(expected_marker, ""))
		_check(expected_prop_name != "",
				"%s start marker %s has an opening prop mapping" % [
						origin.id, expected_marker])
		if expected_prop_name == "":
			continue
		await _run_origin_start_case(origin, expected_prop_name)
	print("Opening beat smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _run_origin_start_case(origin: OriginDef, expected_prop_name: String) -> void:
	await _teardown_main()
	_setup_world(origin, "%s Tester" % origin.id.capitalize())
	await _instantiate_main()
	_test_origin_start_and_opening_beat(origin, expected_prop_name)


func _setup_world(origin: OriginDef, char_name: String) -> void:
	_toasts.clear()
	var sheet := CharacterSheet.new()
	sheet.char_name = char_name
	sheet.origin_id = origin.id
	sheet.cash_cents = origin.starting_cash_cents
	sheet.skills = origin.skill_seeds.duplicate()
	sheet.inventory = origin.starting_items.duplicate()
	sheet.housing_id = origin.starting_housing_id
	for flag in origin.starting_flags:
		sheet.flags[flag] = origin.starting_flags[flag]
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


func _test_origin_start_and_opening_beat(origin: OriginDef, expected_prop_name: String) -> void:
	var player: Node2D = _main.get_node("Player")
	var expected_marker := origin.starting_location_id
	var start_marker := str(WorldState.player_sheet.flags.get("start_location_id", ""))
	var expected := Locations.door_pos(expected_marker)
	_check(start_marker == expected_marker,
			"%s stores %s start marker on the sheet" % [origin.id, expected_marker])
	_check(player.global_position.distance_to(expected) <= 1.0,
			"%s first-life exterior spawn uses %s" % [origin.id, expected_marker])
	_check(expected.x >= 160.0,
			"%s %s start marker is clear of the HUD at the west camera limit" % [origin.id, expected_marker])
	_check(WorldState.player_location_id == "exterior",
			"%s exterior start marker preserves simulation location" % origin.id)
	_check(int(WorldState.player_sheet.flags.get("opening_seen_life", 0)) \
			== WorldState.player_sheet.lives_lived,
			"%s opening beat is recorded for this life" % origin.id)
	var start_toast_text := Locations.display_name(expected_marker)
	_check(_toasts.any(func(t: String) -> bool:
			return origin.display_name in t and start_toast_text in t and origin.opening_line in t),
			"%s opening beat names the origin and start place" % origin.id)
	_check(_current_world_has_node(expected_prop_name),
			"%s opening prop exists near the start marker" % origin.id)
	_check(_hud_objective_matches_origin(origin),
			"%s opening HUD objective matches origin constraints" % origin.id)


func _hud_objective_matches_origin(origin: OriginDef) -> bool:
	var objective := _main.get_node_or_null("HUD/TopLeft/VBox/ObjectiveLabel") as Label
	if objective == null or not objective.visible:
		return false
	var expected_path := "Getting Off the Street" \
			if origin.tags.has("no_papers") else "First Week"
	return expected_path in objective.text


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
