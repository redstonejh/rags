extends Node
## Exercises an in-play warrant arrest through Main, CrimeSystem, an embodied cop,
## and the real Confrontation UI.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/InPlayArrestSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures := 0
var _main: Node = null
var _cop: NPCRecord = null


func _ready() -> void:
	_setup_wanted_world()
	if _cop == null:
		_finish()
		return
	await _instantiate_main()
	await _test_embodied_cop_teardown_is_synchronous()
	await _test_embodied_cop_starts_arrest()
	_finish()


func _finish() -> void:
	print("In-play arrest smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_wanted_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Wanted Driver"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 10 * 60
	_cop = _first_cop()
	if _cop == null:
		_check(false, "world generation created at least one cop")
		return
	_cop.current_location_id = "exterior"
	_cop.current_activity = "patrol"
	_cop.traveling = false
	_cop.flags.erase("bribed_until_day")
	var warrant := CrimeSystem.commit("shoplift", "exterior", null, Locations.door_pos("exterior"))
	_check(warrant.is_active_warrant() and CrimeSystem.wanted_stars() > 0,
			"nearby cop witness creates an active warrant")


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(Locations.door_pos("loc_jail") != Vector2.ZERO,
			"county jail has a real exterior door")
	_check(_current_world_has_node("SignSprite_loc_jail"),
			"county jail has visible exterior signage")
	await get_tree().create_timer(0.6).timeout


func _test_embodied_cop_starts_arrest() -> void:
	print("[Embodied cop arrest]")
	var cop_agent := _cop.agent
	_check(cop_agent != null and is_instance_valid(cop_agent),
			"wanted player has an embodied cop nearby")
	await _place_player_at_cop_patrol_point()
	GameClock.total_minutes = _next_cop_check_minute()
	EventBus.minute_passed.emit(GameClock.total_minutes)
	await get_tree().process_frame
	var confrontation: CanvasLayer = _main.get_node("Confrontation")
	_check(confrontation.visible and GameClock.paused,
			"cop patrol opens the arrest confrontation")
	_check(_descendant_text_contains(confrontation, "Stop right there"),
			"arrest confrontation names the stop")
	var comply := _find_button_containing(confrontation, "Hands up")
	_check(comply != null, "arrest confrontation offers comply")
	if comply == null:
		return
	var day_before := GameClock.day
	comply.pressed.emit()
	_check(_find_button_containing(confrontation, "Hands up") == null,
			"resolved arrest removes stale comply option immediately")
	await get_tree().process_frame
	_check(GameClock.day == day_before + 1, "comply serves the warrant sentence")
	_check(CrimeSystem.wanted_stars() == 0, "serving clears wanted stars")
	var current_world = _main.get("current_world")
	_check(WorldState.player_location_id == "loc_jail" \
			and current_world is Interior \
			and current_world.location_id == "loc_jail",
			"serving moves the player into the jail interior")
	var bunk := _find_amenity("bed")
	_check(bunk != null and "jail bunk" in bunk.display_name,
			"jail interior has a visible cell bunk")
	_check(_descendant_text_contains(confrontation, "Jail days:"),
			"resolved arrest shows jail day summary")
	var leave := _find_button_containing(confrontation, "Walk away")
	_check(leave != null, "resolved arrest offers a way back to play")
	if leave != null:
		leave.pressed.emit()
		await get_tree().process_frame
		_check(not confrontation.visible and not GameClock.paused,
				"leaving arrest returns control to play")


func _test_embodied_cop_teardown_is_synchronous() -> void:
	print("[Embodied NPC teardown]")
	var cop_agent := _cop.agent
	_check(cop_agent != null and is_instance_valid(cop_agent),
			"cop starts embodied before teardown")
	if cop_agent == null or not is_instance_valid(cop_agent):
		return
	var parent := cop_agent.get_parent()
	SimEngine.despawn_npc(_cop)
	_check(_cop.agent == null, "despawn clears the NPC record agent")
	_check(parent != null and not parent.get_children().has(cop_agent),
			"despawn detaches the old agent synchronously")
	await get_tree().create_timer(0.6).timeout
	_check(_cop.agent != null and is_instance_valid(_cop.agent),
			"wanted cop can re-embody after synchronous teardown")


func _place_player_at_cop_patrol_point() -> void:
	var player := _main.get_node_or_null("Player") as Node2D
	if player == null:
		return
	_cop.current_location_id = "exterior"
	_cop.current_activity = "patrol"
	_cop.traveling = false
	player.global_position = _cop.abstract_position(GameClock.total_minutes)
	await get_tree().physics_frame


func _next_cop_check_minute() -> int:
	var total := GameClock.total_minutes
	var remainder := total % CrimeSystem.COP_CHECK_MINUTES
	return total if remainder == 0 else total + CrimeSystem.COP_CHECK_MINUTES - remainder


func _first_cop() -> NPCRecord:
	for npc in WorldState.npcs.values():
		if npc.is_cop():
			return npc
	return null


func _find_button_containing(node: Node, text: String) -> Button:
	if node is Button and text in str(node.text):
		return node
	for child in node.get_children():
		var found := _find_button_containing(child, text)
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


func _current_world_has_node(node_name: String) -> bool:
	if _main == null:
		return false
	return _find_named_descendant(_main.get("current_world"), node_name) != null


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


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
