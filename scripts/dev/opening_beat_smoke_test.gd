extends Node
## Exercises origin start markers and the first-day opening beat through Main.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/OpeningBeatSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures := 0
var _main: Node = null
var _toasts: Array[String] = []


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	await _test_origin_start_and_opening_beat()
	print("Opening beat smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Arrival Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 40000
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


func _test_origin_start_and_opening_beat() -> void:
	var player: Node2D = _main.get_node("Player")
	var start_marker := str(WorldState.player_sheet.flags.get("start_location_id", ""))
	var expected := Locations.door_pos("loc_bus_stop")
	_check(start_marker == "loc_bus_stop", "origin start marker is stored on the sheet")
	_check(player.global_position.distance_to(expected) <= 1.0,
			"first-life exterior spawn uses the origin start marker")
	_check(WorldState.player_location_id == "exterior",
			"exterior start marker preserves simulation location")
	_check(int(WorldState.player_sheet.flags.get("opening_seen_life", 0)) \
			== WorldState.player_sheet.lives_lived,
			"opening beat is recorded for this life")
	_check(_toasts.any(func(t: String) -> bool:
			return "Small-Town Transplant" in t and "bus stop" in t),
			"opening beat names the origin and start place")


func _on_toast(message: String) -> void:
	_toasts.append(message)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
