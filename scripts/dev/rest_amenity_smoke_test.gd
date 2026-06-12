extends Node
## Exercises real rest interaction through Main, Player input, and Amenity.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/RestAmenitySmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const HOME_LAYOUT_IDS := [
	"shelter_cot",
	"weekly_motel",
	"bricks_unit",
	"decent_apartment",
	"small_house",
	"penthouse",
]

var failures := 0
var _main: Node = null
var _player: Node = null


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	await _test_home_layouts_by_tier()
	await _test_bed_sleep_interaction()
	await _test_shower_interaction()
	await _test_tv_interaction()
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


func _test_home_layouts_by_tier() -> void:
	var seen := {}
	var sheet := WorldState.player_sheet
	for housing_id in HOME_LAYOUT_IDS:
		sheet.housing_id = housing_id
		EventBus.travel_requested.emit("loc_bricks")
		await get_tree().process_frame
		await get_tree().physics_frame
		var world = _main.get("current_world")
		var layout_id := str(world.get("layout_id")) if world != null else ""
		seen[layout_id] = true
		_check(layout_id == housing_id,
				"%s home resolves to its own interior layout" % housing_id)
		_check(_find_amenity("bed") != null,
				"%s home has a visible sleep spot" % housing_id)
		_check(_current_world_name_prefix_count("DecorSprite") > 0,
				"%s home has visible decor" % housing_id)
	_check(seen.size() == HOME_LAYOUT_IDS.size(),
			"housing tier interiors are visually distinct")
	sheet.housing_id = "bricks_unit"
	EventBus.travel_requested.emit("loc_bricks")
	await get_tree().process_frame
	await get_tree().physics_frame


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
	_check(_survival_feedback_kind() == "sleep",
			"bed sleep shows the survival feedback vignette")
	_check(_survival_feedback_detail().contains("Energy +"),
			"bed sleep vignette reports energy gain")
	_check(not GameClock.paused and GameClock.pause_lock_count() == 0,
			"bed sleep returns control without pause locks")


func _test_shower_interaction() -> void:
	var shower := _find_amenity("shower")
	_check(shower != null, "owned home shower exists")
	if shower == null:
		return
	var sheet := WorldState.player_sheet
	sheet.needs.values["hygiene"] = 15.0
	var hygiene_before := sheet.needs.get_value("hygiene")
	_interact_with(shower)
	await get_tree().process_frame
	_check(sheet.needs.get_value("hygiene") > hygiene_before,
			"shower restores hygiene")
	_check(_survival_feedback_kind() == "shower",
			"shower shows the survival feedback vignette")
	_check(_survival_feedback_detail().contains("Hygiene +"),
			"shower vignette reports hygiene gain")
	_check(not GameClock.paused and GameClock.pause_lock_count() == 0,
			"shower leaves no pause locks")


func _test_tv_interaction() -> void:
	var tv := _find_amenity("tv")
	_check(tv != null, "owned home TV exists")
	if tv == null:
		return
	var sheet := WorldState.player_sheet
	sheet.needs.values["fun"] = 10.0
	var fun_before := sheet.needs.get_value("fun")
	_interact_with(tv)
	await get_tree().process_frame
	_check(sheet.needs.get_value("fun") > fun_before,
			"TV restores fun")
	_check(_survival_feedback_kind() == "fun",
			"TV shows the survival feedback vignette")
	_check(_survival_feedback_detail().contains("Fun +"),
			"TV vignette reports fun gain")
	_check(not GameClock.paused and GameClock.pause_lock_count() == 0,
			"TV leaves no pause locks")


func _interact_with(amenity: Amenity) -> void:
	amenity.interact(_player)


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


func _current_world_name_prefix_count(prefix: String) -> int:
	var current_world: Node = _main.get("current_world")
	return _count_name_prefix_descendants(current_world, prefix)


func _count_name_prefix_descendants(node: Node, prefix: String) -> int:
	if node == null:
		return 0
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_name_prefix_descendants(child, prefix)
	return count


func _survival_feedback_kind() -> String:
	var feedback := _main.get_node_or_null("SurvivalFeedback")
	return str(feedback.get_meta("last_survival_kind", "")) if feedback != null else ""


func _survival_feedback_detail() -> String:
	var feedback := _main.get_node_or_null("SurvivalFeedback")
	return str(feedback.get_meta("last_survival_detail", "")) if feedback != null else ""


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
