extends Node
## Exercises save/load through the real Main scene and pause-menu Save button.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/RealSaveLoadSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
var failures := 0
var _main: Node = null
var _loaded_main: Node = null
var _save_guard := SaveSlotGuard.new()
var _case_id := ""
var _cop_id := ""
var _cop_rel_before := 0.0
var _seed_before := 0
var _time_before := 0


func _ready() -> void:
	_save_guard.backup()
	await _test_real_scene_save_load()
	_restore_save_files()
	print("Real save/load smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _test_real_scene_save_load() -> void:
	_setup_world()
	await _instantiate_main()
	await _travel_to_store()
	_create_persistent_state()
	await _save_through_pause_menu()
	_corrupt_primary_save()
	await _reload_from_disk()
	_load_from_backup_without_primary()
	await _instantiate_loaded_main()


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Save Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 43210
	sheet.bank_cents = 1234
	sheet.flags["has_id"] = true
	sheet.flags["outfit"] = "nice_suit"
	WorldState.new_world(sheet)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 13 * 60 + 25
	SaveManager.set_in_game(true)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(_main.get("current_world") != null, "main scene creates an initial world")


func _travel_to_store() -> void:
	EventBus.travel_requested.emit("loc_store")
	await get_tree().process_frame
	await get_tree().physics_frame
	var current_world: Node = _main.get("current_world")
	_check(WorldState.player_location_id == "loc_store",
			"production travel updates the saved player location")
	_check(current_world is Interior and current_world.location_id == "loc_store",
			"main scene entered the store interior")


func _create_persistent_state() -> void:
	_seed_before = WorldState.world_seed
	_time_before = GameClock.total_minutes
	var cop := _first_cop()
	if cop == null:
		_check(false, "world generation created at least one cop")
		return
	_cop_id = cop.id
	cop.current_location_id = "exterior"
	cop.current_activity = "patrol"
	cop.traveling = false
	cop.relationships["player"] = -12.0
	var case := CrimeSystem.commit("shoplift", "exterior", null, Locations.door_pos("exterior"))
	_case_id = case.id
	_cop_rel_before = cop.rel("player")
	WorldState.add_news("SAVE TEST: QuikStop whispers about a very memorable jacket.")
	_check(case.is_active_warrant(), "crime case state exists before save")


func _save_through_pause_menu() -> void:
	_main.call("_unhandled_input", _action("ui_cancel"))
	await get_tree().process_frame
	var stack: Node = _main.get_node("UIStack")
	_check(stack.call("is_modal_open", "pause_menu") and GameClock.paused,
			"pause menu opens before save")
	var save_button := _find_button_with_text(stack, "Save")
	_check(save_button != null, "pause menu exposes Save")
	if save_button == null:
		return
	save_button.pressed.emit()
	await get_tree().process_frame
	_check(SaveManager.has_save(), "pause-menu Save writes the ironman file")
	_check(_descendant_text_contains(stack, "Saved."), "pause menu confirms save")


func _corrupt_primary_save() -> void:
	var copied := DirAccess.copy_absolute(SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + ".bak")
	_check(copied == OK and FileAccess.file_exists(SaveManager.SAVE_PATH + ".bak"),
			"test backup save exists before corruption")
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	_check(f != null, "test can corrupt the primary save")
	if f == null:
		return
	f.store_string("{ this is not a save")
	f.close()


func _reload_from_disk() -> void:
	_teardown_main()
	await get_tree().process_frame
	WorldState.player_sheet = null
	WorldState.npcs.clear()
	WorldState.crime_cases.clear()
	WorldState.player_location_id = "exterior"
	WorldState.world_seed = -1
	GameClock.total_minutes = 0
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)

	var loaded := SaveManager.load_game()
	_check(loaded, "load_game falls back to backup after primary corruption")
	_check(_save_file_has_player(SaveManager.SAVE_PATH, "Save Walker"),
			"backup fallback repairs the primary save")
	_check(WorldState.player_sheet != null and WorldState.player_sheet.char_name == "Save Walker",
			"player sheet reloads from disk")
	_check(WorldState.player_sheet != null and WorldState.player_sheet.cash_cents == 43210,
			"player cash reloads from disk")
	_check(WorldState.player_sheet != null and WorldState.player_sheet.flags.get("outfit", "") == "nice_suit",
			"player outfit flag reloads from disk")
	_check(WorldState.player_location_id == "loc_store",
			"saved interior location reloads")
	_check(GameClock.total_minutes == _time_before, "clock reloads")
	_check(WorldState.world_seed == _seed_before and WorldState.npcs.has(_cop_id),
			"same generated town reloads")
	var cop: NPCRecord = WorldState.npcs.get(_cop_id)
	_check(cop != null and absf(cop.rel("player") - _cop_rel_before) < 0.01,
			"NPC relationship reloads")
	_check(WorldState.crime_cases.has(_case_id) and CrimeSystem.wanted_stars() > 0,
			"crime case and wanted stars reload")
	_check(not WorldState.gazette.is_empty() and "SAVE TEST" in str(WorldState.gazette.back().get("text", "")),
			"gazette history reloads")


func _load_from_backup_without_primary() -> void:
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	WorldState.player_sheet = null
	WorldState.npcs.clear()
	WorldState.crime_cases.clear()
	var loaded := SaveManager.load_game()
	_check(loaded, "load_game uses backup when primary is missing")
	_check(_save_file_has_player(SaveManager.SAVE_PATH, "Save Walker"),
			"backup-only load recreates the primary save")
	_check(WorldState.player_sheet != null and WorldState.player_sheet.char_name == "Save Walker",
			"backup-only load restores the player")


func _instantiate_loaded_main() -> void:
	SaveManager.set_in_game(true)
	_loaded_main = MAIN_SCENE.instantiate()
	add_child(_loaded_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var current_world: Node = _loaded_main.get("current_world")
	_check(current_world is Interior and current_world.location_id == "loc_store",
			"loaded main scene re-enters the saved interior")
	_check(SimEngine.spawn_host == current_world,
			"SimEngine spawn host follows the loaded scene")
	_teardown_loaded_main()


func _first_cop() -> NPCRecord:
	for npc in WorldState.npcs.values():
		if npc.is_cop():
			return npc
	return null


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null


func _teardown_loaded_main() -> void:
	if _loaded_main != null and is_instance_valid(_loaded_main):
		_loaded_main.queue_free()
	_loaded_main = null


func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and str(node.text) == text:
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _descendant_text_contains(node: Node, text: String) -> bool:
	var value = node.get("text")
	if value != null and str(value).contains(text):
		return true
	for child in node.get_children():
		if _descendant_text_contains(child, text):
			return true
	return false


func _save_file_has_player(path: String, expected_name: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return false
	var world: Dictionary = parser.data.get("world", {})
	var player: Dictionary = world.get("player", {})
	return str(player.get("char_name", "")) == expected_name


func _restore_save_files() -> void:
	SaveManager.set_in_game(false)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	_teardown_main()
	_teardown_loaded_main()
	_save_guard.restore()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
