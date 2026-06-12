extends Node
## Regression coverage for Phase 0 modal/pause ownership.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/UIStackSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures: int = 0
var _main: Node = null


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	_test_pause_locks()
	_test_panel_overlap()
	_test_escape_pause_menu()
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
