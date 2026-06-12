extends Node
## Exercises heir selection through the real death screen.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/DeathHeirSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures := 0
var _main: Node = null


func _ready() -> void:
	_setup_parent_life()
	await _instantiate_main()
	await _test_death_screen_heir_choice()
	print("Death heir smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_parent_life() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Legacy Parent"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.bank_cents = 12500
	sheet.housing_id = "house"
	sheet.furniture = ["lux_bed"]
	sheet.flags["has_id"] = true
	sheet.flags["home_owned"] = true
	sheet.children = [{
		"name": "Dot",
		"born_day": GameClock.day - int(Body.DAYS_PER_YEAR * 17.0),
		"traits": ["sunny"],
	}]
	WorldState.new_world(sheet)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame


func _test_death_screen_heir_choice() -> void:
	print("[Death screen heir choice]")
	var seed_before := WorldState.world_seed
	var population_before := WorldState.npcs.size()
	var estate_cents := WorldState.player_sheet.cash_cents + WorldState.player_sheet.bank_cents
	EventBus.player_died.emit("testing")
	await get_tree().process_frame
	var heir_button := _find_button_containing(_main, "Continue as Dot")
	_check(heir_button != null and GameClock.paused,
			"death screen offers grown-child heir choice")
	if heir_button == null:
		return
	heir_button.pressed.emit()
	var heir := WorldState.player_sheet
	_check(heir != null and heir.char_name == "Dot Parent",
			"heir button installs the inherited player sheet")
	_check(heir.lives_lived == 2 and heir.flags.get("heir_of", "") == "Legacy Parent",
			"heir sheet records legacy parentage")
	_check(heir.cash_cents == estate_cents and heir.housing_id == "house" \
			and heir.flags.get("home_owned", false),
			"heir inherits estate cash and owned home")
	_check(heir.flags.get("childhood_sunny", false),
			"heir carries childhood trait flags")
	_check(WorldState.world_seed == seed_before and WorldState.npcs.size() == population_before,
			"heir continues in the existing town")


func _find_button_containing(node: Node, text: String) -> Button:
	if node is Button and text in str(node.text):
		return node
	for child in node.get_children():
		var found := _find_button_containing(child, text)
		if found != null:
			return found
	return null


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
