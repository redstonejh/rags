extends Node
## Regression coverage for Phase 0 modal/pause ownership and player control.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/UIStackSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures: int = 0
var _main: Node = null
var _player: Node = null
var _travel_requested_location := ""


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	_test_pause_locks()
	_test_panel_overlap()
	_test_escape_pause_menu()
	await _test_click_move()
	await _test_wasd_cancels_click_move()
	_test_click_move_interacts()
	_test_pause_menu_walk_away()
	print("UIStack smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Modal Tester"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player")


func _test_pause_locks() -> void:
	print("[Pause locks]")
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	_check(not GameClock.paused, "clock starts unpaused")
	GameClock.push_pause_lock("a")
	GameClock.push_pause_lock("b")
	_check(GameClock.paused and GameClock.pause_lock_count() == 2, "two locks pause once")
	GameClock.release_pause_lock("a")
	_check(GameClock.paused and GameClock.pause_lock_count() == 1, "releasing one lock keeps pause")
	GameClock._unhandled_input(_action("time_speed_3"))
	_check(GameClock.paused and is_equal_approx(GameClock.time_scale, 12.0), "speed keys do not break modal pause")
	GameClock.release_pause_lock("b")
	_check(not GameClock.paused, "last lock resumes clock")
	GameClock.set_manual_paused(true)
	GameClock.push_pause_lock("modal")
	GameClock.release_pause_lock("modal")
	_check(GameClock.paused, "manual pause survives modal close")
	GameClock.set_manual_paused(false)


func _test_panel_overlap() -> void:
	print("[Panel overlap]")
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	var phone: CanvasLayer = _main.get_node("Phone")
	var inventory: CanvasLayer = _main.get_node("Inventory")
	phone._unhandled_input(_action("phone"))
	_check(phone.visible and GameClock.paused, "phone opens and pauses")
	inventory._unhandled_input(_action("inventory"))
	_check(inventory.visible and GameClock.pause_lock_count() == 2, "inventory stacks with phone")
	phone._unhandled_input(_action("phone"))
	_check(not phone.visible and inventory.visible and GameClock.paused, "closing phone keeps inventory pause")
	inventory._unhandled_input(_action("inventory"))
	_check(not inventory.visible and not GameClock.paused, "closing final panel resumes")


func _test_escape_pause_menu() -> void:
	print("[Esc pause menu]")
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	var stack: Node = _main.get_node("UIStack")
	_main._unhandled_input(_action("ui_cancel"))
	_check(stack.call("is_modal_open", "pause_menu") and GameClock.paused, "Esc opens pause menu")
	_main._unhandled_input(_action("ui_cancel"))
	_check(not stack.call("is_modal_open", "pause_menu") and not GameClock.paused, "Esc closes pause menu")


func _test_click_move() -> void:
	print("[Click-to-move]")
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	var start: Vector2 = _player.get("global_position")
	_player.call("set_move_target", start + Vector2(160, 0))
	await _physics_frames(30)
	var current: Vector2 = _player.get("global_position")
	_check(current.distance_to(start) > 24.0, "click target moves the player")
	_check(_player.call("has_click_target"), "path remains active before arrival")


func _test_wasd_cancels_click_move() -> void:
	print("[Manual control priority]")
	var current: Vector2 = _player.get("global_position")
	_player.call("set_move_target", current + Vector2(160, 0))
	Input.action_press("move_left")
	await get_tree().physics_frame
	Input.action_release("move_left")
	_check(not _player.call("has_click_target"), "WASD cancels click path")


func _test_click_move_interacts() -> void:
	print("[Click-to-interact]")
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	var diner_door := _find_exterior_door("loc_diner")
	if diner_door == null:
		_check(false, "diner door exists")
		return
	_travel_requested_location = ""
	if not EventBus.travel_requested.is_connected(_on_test_travel_requested):
		EventBus.travel_requested.connect(_on_test_travel_requested)
	_player.set("global_position", diner_door.get("global_position") + Vector2(0, 10))
	_player.call("set_move_target", diner_door.get("global_position"), diner_door)
	_player.call("_physics_process", 0.0)
	_check(_travel_requested_location == "loc_diner", "click target interacts after walking into range")
	_check(not _player.call("has_click_target"), "click path clears after interaction")


func _test_pause_menu_walk_away() -> void:
	print("[Pause menu Walk Away]")
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	var sheet: CharacterSheet = WorldState.player_sheet
	var expected_npc_id := "npc_walked_%02d" % sheet.lives_lived
	var stack: Node = _main.get_node("UIStack")
	_main._unhandled_input(_action("ui_cancel"))
	var walk_button := _find_button_with_text(stack, "Walk Away")
	_check(walk_button != null and stack.call("is_modal_open", "pause_menu"),
			"pause menu exposes Walk Away")
	if walk_button == null:
		return
	walk_button.pressed.emit()
	var old_self: NPCRecord = WorldState.npcs.get(expected_npc_id)
	_check(not sheet.alive, "Walk Away ends the controlled life")
	_check(old_self != null and old_self.display_name == "Modal Tester" \
			and old_self.flags.get("was_player_life", -1) == sheet.lives_lived,
			"Walk Away turns the player into a persistent NPC")


func _find_exterior_door(location_id: String) -> Node:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return null
	var town: Node = world_root.get_child(0)
	for child in town.get_children():
		if child.get("target_location_id") == location_id:
			return child
	return null


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and str(node.text) == text:
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _on_test_travel_requested(location_id: String) -> void:
	_travel_requested_location = location_id


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


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
