extends Node
## Scripted Phase 0 playtest harness.
## Runs the real gameplay scene, captures checkpoint screenshots, and fails
## loudly if a checkpoint renders blank or a core UI/input path breaks.
##
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/PlaytestDriver.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const OUT_DIR := "user://playtests"

var failures: int = 0
var _main: Node = null
var _player: Node = null
var _shop_counter: Node = null
var _shots: Array[String] = []


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	await _checkpoint("01_spawn")
	await _walk_toward_diner()
	await _checkpoint("02_approach_diner")
	await _enter_diner()
	await _checkpoint("03_inside_diner")
	await _verify_date_scene_ui()
	await _open_phone()
	await _checkpoint("04_phone")
	await _close_phone_open_inventory()
	await _checkpoint("05_inventory")
	await _enter_store_move_to_counter()
	await _checkpoint("06_store_counter")
	await _open_shop_from_counter()
	await _checkpoint("07_shop")
	await _open_pause_menu()
	await _checkpoint("08_pause_menu")
	_report()
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	_prepare_output_dir()
	var sheet := CharacterSheet.new()
	sheet.char_name = "Harness Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	_seed_people_app_state()
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		_check(false, "playtest output directory opens")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			var err := dir.remove(file_name)
			if err != OK:
				_check(false, "removed stale playtest screenshot %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _seed_people_app_state() -> void:
	var people: Array = WorldState.npcs.values()
	if people.size() < 2:
		_check(false, "people app seed has enough NPCs")
		return
	var date: NPCRecord = people[0]
	var rival: NPCRecord = people[1]
	var friend_a: NPCRecord = people[6] if people.size() > 6 else null
	var friend_b: NPCRecord = people[7] if people.size() > 7 else null
	date.relationships["player"] = 62.0
	date.relationships[rival.id] = -45.0
	if friend_a != null:
		date.relationships[friend_a.id] = 57.0
	if friend_b != null:
		date.relationships[friend_b.id] = 49.0
	date.flags["dating_player"] = true
	date.add_memory("date", "player", "said yes to a date with you", 1.0, 7.0)
	rival.relationships["player"] = -38.0
	rival.relationships[date.id] = -45.0
	rival.add_memory("witnessed", "player", "were seen arguing outside Mel's", -0.4, 5.0, true)
	rival.memories.back()["source_id"] = date.id
	rival.add_memory("favor", "player", "helped at the clinic after midnight", 0.4, 4.0)
	if people.size() >= 6:
		var spouse: NPCRecord = people[5]
		spouse.relationships["player"] = 82.0
		spouse.flags["married_to_player"] = true
		WorldState.player_sheet.flags["spouse_id"] = spouse.id
		WorldState.player_sheet.children = [{
			"name": "Dot",
			"born_day": GameClock.day - 12,
			"traits": ["observant"],
		}]
		rival.memories.back()["previous_source_id"] = spouse.id


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player")
	_check(_player_has_walk_sheets(), "player uses layered walk sheets")
	await _verify_player_outfit_switch()
	_verify_hud_time_hint_fit()
	await _verify_hud_objective_tracker()
	await _verify_social_playthrough()
	_check(_exterior_ground_tile_count(Vector2i(5, 0)) > 0, "exterior sidewalks spawned")
	_check(_exterior_ground_tile_count(Vector2i(6, 0)) > 0, "exterior dirt lots spawned")
	_check(_exterior_facade_count() > 0, "exterior building facades spawned")
	_check(_exterior_street_prop_count() > 0, "exterior street props spawned")


func _walk_toward_diner() -> void:
	var door := _find_exterior_door("loc_diner")
	if door == null:
		_check(false, "diner door exists")
		return
	var start: Vector2 = _player.get("global_position")
	_player.call("set_move_target", door.get("global_position"))
	await _physics_frames(24)
	var current: Vector2 = _player.get("global_position")
	_check(current.distance_to(start) > 16.0, "scripted player movement advanced")
	var body: Sprite2D = _player.get_node("BodySprite")
	_check(body.frame_coords != Vector2i(1, 0), "player walk animation responds to movement")


func _enter_diner() -> void:
	# Use the production travel path after movement has been proven; this avoids
	# scene replacement in the middle of a path-follow await.
	EventBus.travel_requested.emit("loc_diner")
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(WorldState.player_location_id == "loc_diner", "travel entered the diner")
	_check(_current_world_named_count("PropSprite") > 0, "interior prop sprites spawned")
	_move_player_to_current_world_cell(Vector2i(7, 4))
	await get_tree().physics_frame


func _open_phone() -> void:
	var phone: CanvasLayer = _main.get_node("Phone")
	phone._unhandled_input(_action("phone"))
	await get_tree().process_frame
	_check(phone.visible and GameClock.paused, "phone opened from input event")
	_check(phone.call("open_tab", "People"), "phone People tab selectable")
	await get_tree().process_frame
	var people_content := _find_named_descendant(phone, "PeopleContent")
	_check(people_content != null, "phone People content exists")
	_check(_descendant_text_contains(people_content, "known contacts"),
			"People tab hides unknown townsfolk")
	_check(_descendant_text_contains(people_content, "dating you"), "People tab shows dating status")
	_check(_descendant_text_contains(people_content, "close to") \
			and _descendant_text_contains(people_content, ", "),
			"People tab shows compact social circles")
	_check(_descendant_text_contains(people_content, "Family: spouse; 1 child"),
			"People tab shows family status")
	_check(_descendant_text_contains(people_content, " via "),
			"People tab shows gossip source chains")
	_check(_descendant_text_contains(people_content, "Gossip:"), "People tab shows gossip")
	_check(_descendant_text_contains(people_content, "Stories:") \
			and _descendant_text_contains(people_content, "clinic after midnight"),
			"People tab shows a compact story history")
	_check(not _descendant_text_contains(people_content, "misjudged you in public"),
			"People tab phrases player memories from the player's view")


func _verify_date_scene_ui() -> void:
	var npcs: Array = WorldState.npcs.values()
	if npcs.is_empty():
		_check(false, "dating scene has a seeded NPC")
		return
	var date: NPCRecord = npcs[0]
	date.relationships["player"] = maxf(date.rel("player"), 62.0)
	date.flags["dating_player"] = true
	date.current_location_id = "loc_diner"
	date.current_activity = "idle"
	date.traveling = false
	EventBus.dialogue_requested.emit(date.id)
	await get_tree().process_frame
	var dialogue: CanvasLayer = _main.get_node("Dialogue")
	dialogue.call("_do_action", "date_mels")
	await get_tree().process_frame
	var choice := _find_named_descendant(dialogue, "DateChoice_date_mels_listen")
	_check(choice is Button and str(choice.text).contains("week"),
			"date activity opens venue choices")
	await _checkpoint("03_date_scene")
	var before := date.rel("player")
	if choice is Button:
		choice.pressed.emit()
	await get_tree().process_frame
	_check(date.rel("player") > before, "date scene choice changes relationship")
	_check(WorldState.player_location_id == "loc_diner" and date.current_location_id == "loc_diner",
			"date scene choice keeps couple at venue")
	dialogue._unhandled_input(_action("ui_cancel"))
	await get_tree().process_frame


func _close_phone_open_inventory() -> void:
	var phone: CanvasLayer = _main.get_node("Phone")
	var inventory: CanvasLayer = _main.get_node("Inventory")
	WorldState.player_sheet.needs.values["hunger"] = 40.0
	WorldState.player_sheet.inventory.append("instant_noodles")
	WorldState.player_sheet.flags["calories_today"] = 0
	phone._unhandled_input(_action("phone"))
	inventory._unhandled_input(_action("inventory"))
	await get_tree().process_frame
	_check(not phone.visible and inventory.visible and GameClock.paused, "inventory opened after phone")
	var use_button := _find_button_with_text(inventory, "Use")
	_check(use_button != null, "inventory exposes consumable use button")
	if use_button != null:
		use_button.pressed.emit()
		await get_tree().process_frame
	_check(WorldState.player_sheet.needs.get_value("hunger") > 40.0,
			"inventory Use restores hunger")
	_check(int(WorldState.player_sheet.flags.get("calories_today", 0)) > 0,
			"inventory Use logs calories")
	_check("instant_noodles" not in WorldState.player_sheet.inventory,
			"inventory Use removes one consumed item")
	_check(_survival_feedback_kind() == "eat",
			"inventory Use shows the survival feedback vignette")


func _enter_store_move_to_counter() -> void:
	var inventory: CanvasLayer = _main.get_node("Inventory")
	if inventory.visible:
		inventory._unhandled_input(_action("inventory"))
	await get_tree().process_frame
	EventBus.travel_requested.emit("loc_store")
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(WorldState.player_location_id == "loc_store", "travel entered the store")
	_shop_counter = _find_current_world_node_with_property("stock")
	if _shop_counter == null:
		_check(false, "shop counter exists")
		return
	_check(true, "shop counter exists")
	_player.set("global_position", _shop_counter.get("global_position"))
	_reset_player_camera_smoothing()
	await get_tree().physics_frame


func _open_shop_from_counter() -> void:
	if _shop_counter == null:
		_check(false, "shop counter available for interaction")
		return
	await get_tree().physics_frame
	_player.call("_physics_process", 0.0)
	_player.call("_unhandled_input", _action("interact"))
	await get_tree().process_frame
	var shop: CanvasLayer = _main.get_node("Shop")
	_check(shop.visible and GameClock.paused, "shop opened from interact input")
	var buy_noodles := _find_named_descendant(shop, "Buy_instant_noodles") as Button
	_check(buy_noodles != null and not buy_noodles.disabled,
			"shop exposes a named food purchase button")
	if buy_noodles != null:
		var cash_before := WorldState.player_sheet.cash_cents
		buy_noodles.pressed.emit()
		await get_tree().process_frame
		_check(WorldState.player_sheet.cash_cents < cash_before,
				"shop purchase spends cash")
		_check("instant_noodles" in WorldState.player_sheet.inventory,
				"shop purchase adds food to inventory")


func _open_pause_menu() -> void:
	var inventory: CanvasLayer = _main.get_node("Inventory")
	if inventory.visible:
		inventory._unhandled_input(_action("inventory"))
	var shop: CanvasLayer = _main.get_node("Shop")
	if shop.visible:
		shop._unhandled_input(_action("ui_cancel"))
	_main._unhandled_input(_action("ui_cancel"))
	await get_tree().process_frame
	var stack: Node = _main.get_node("UIStack")
	_check(stack.call("is_modal_open", "pause_menu") and GameClock.paused, "pause menu opened from Esc")


func _checkpoint(id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("  SKIP: screenshot %s unavailable under headless renderer" % id)
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		_check(false, "viewport texture available for screenshot %s" % id)
		return
	var img := texture.get_image()
	if img == null:
		_check(false, "captured screenshot image %s" % id)
		return
	var path := "%s/%s.png" % [OUT_DIR, id]
	var err := img.save_png(path)
	_check(err == OK, "saved screenshot %s" % id)
	_check(_image_has_content(img), "screenshot %s is nonblank" % id)
	_shots.append(ProjectSettings.globalize_path(path))


func _image_has_content(img: Image) -> bool:
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return false
	var first := img.get_pixel(0, 0)
	var samples := 0
	for x in range(0, img.get_width(), maxi(1, img.get_width() / 8)):
		for y in range(0, img.get_height(), maxi(1, img.get_height() / 8)):
			samples += 1
			if img.get_pixel(x, y) != first:
				return true
	return samples > 0 and first.a > 0.0 and first.get_luminance() > 0.01


func _find_exterior_door(location_id: String) -> Node:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return null
	for child in world_root.get_child(0).get_children():
		if child.get("target_location_id") == location_id:
			return child
	return null


func _player_has_walk_sheets() -> bool:
	var body: Sprite2D = _player.get_node("BodySprite")
	var outfit: Sprite2D = _player.get_node("OutfitSprite")
	return body.hframes == 4 and body.vframes == 4 \
			and outfit.hframes == 4 and outfit.vframes == 4


func _verify_player_outfit_switch() -> void:
	WorldState.player_sheet.inventory.append("nice_suit")
	WorldState.player_sheet.flags["outfit"] = "nice_suit"
	await get_tree().physics_frame
	var outfit: Sprite2D = _player.get_node("OutfitSprite")
	_check(outfit.texture != null \
			and outfit.texture.resource_path.ends_with("outfit_nice_suit_walk.png"),
			"player outfit sprite follows worn clothing")


func _verify_hud_time_hint_fit() -> void:
	var label := _main.get_node_or_null("HUD/TopLeft/VBox/SpeedLabel") as Label
	var top_left := _main.get_node_or_null("HUD/TopLeft") as Control
	var backing := _main.get_node_or_null("HUD/TopLeftBack") as ColorRect
	_check(label != null and top_left != null and label.size.x <= top_left.size.x,
			"HUD time hint fits the status panel")
	_check(backing != null and backing.visible and backing.color.a > 0.0,
			"HUD status panel has readable backing")


func _verify_hud_objective_tracker() -> void:
	var objective := _main.get_node_or_null("HUD/TopLeft/VBox/ObjectiveLabel") as Label
	_check(objective != null and objective.visible,
			"HUD objective tracker is visible")
	_check(objective != null and "First Week" in objective.text \
			and "Jobs" in objective.text,
			"HUD objective points a new player toward work")
	WorldState.player_sheet.job_id = "dishwasher"
	EventBus.player_job_changed.emit("dishwasher")
	await get_tree().process_frame
	_check(objective != null and "First Week" in objective.text \
			and "first Dishwasher shift" in objective.text,
			"HUD objective advances from hiring to the first shift")


func _verify_social_playthrough() -> void:
	var npcs: Array = WorldState.npcs.values()
	if npcs.size() < 5:
		_check(false, "social playthrough has enough NPCs")
		return
	var target: NPCRecord = npcs[2]
	var witness: NPCRecord = npcs[3]
	var stranger: NPCRecord = npcs[4]
	_prepare_social_playthrough_records(target, witness, stranger)

	EventBus.dialogue_requested.emit(target.id)
	await get_tree().process_frame
	var dialogue: CanvasLayer = _main.get_node("Dialogue")
	var portrait := _find_named_descendant(dialogue, "Portrait")
	var scrim := _find_named_descendant(dialogue, "DialogueScrim")
	_check(dialogue.visible and portrait is TextureRect and portrait.texture != null,
			"dialogue opens with NPC portrait")
	_check(scrim is ColorRect and scrim.visible and scrim.color.a >= 0.35,
			"dialogue stages conversation with a readable scrim")
	dialogue.call("_do_action_with_roll", "chat")
	await get_tree().process_frame
	_check(_dialogue_result_has_text(dialogue), "dialogue chat produces a response")
	var before_flirt := target.rel("player")
	dialogue.call("_do_action_with_roll", "flirt", 0.0)
	await get_tree().process_frame
	_check(target.rel("player") > before_flirt, "dialogue flirt changes relationship")
	target.relationships["player"] = 0.0
	_place_social_playtest_records(target, witness, stranger)
	var camera := _player.get_node_or_null("Camera2D")
	var before_pulses := int(camera.get_meta("reality_check_pulses", 0)) if camera != null else -1
	var sting := _main.get_node_or_null("RealityCheckSting") as AudioStreamPlayer
	var before_stings := int(sting.get_meta("reality_check_stings", 0)) if sting != null else -1
	dialogue.call("_do_action_with_roll", "threaten", 0.99)
	await get_tree().process_frame
	await get_tree().process_frame
	var collapse := _find_named_descendant(dialogue, "RealityCheckLabel")
	_check(collapse is Label and collapse.visible and str(collapse.text).contains("REALITY CHECK") \
			and str(collapse.text).contains("->"),
			"dialogue shows Reality Check odds collapse")
	_check(_descendant_text_contains_all(dialogue, ["Threaten", "->"]),
			"Reality Check marks the collapsed action button")
	_check(camera != null and int(camera.get_meta("reality_check_pulses", 0)) > before_pulses \
			and str(camera.get_meta("last_reality_check_target", "")) == target.id,
			"Reality Check pulses the player camera")
	_check(sting != null and sting.stream != null \
			and int(sting.get_meta("reality_check_stings", 0)) > before_stings \
			and str(sting.get_meta("last_reality_check_target", "")) == target.id,
			"Reality Check plays the generated sting")
	await _checkpoint("00_dialogue")
	dialogue._unhandled_input(_action("ui_cancel"))
	await get_tree().process_frame

	_check(int(target.flags.get("reacting_until_min", -1)) > GameClock.total_minutes \
			and target.flags.get("reaction_target_id", "") == "player" \
			and target.flags.get("reaction_kind", "") == "called_out",
			"Reality Check target calls out the player")
	_check(witness.memories.any(func(m: Dictionary) -> bool:
		return m.get("subject", "") == "player" and "misjudge" in str(m.get("text", ""))),
			"Reality Check witness records the public miss")
	_check(int(witness.flags.get("reacting_until_min", -1)) > GameClock.total_minutes \
			and witness.flags.get("reaction_target_id", "") == target.id,
			"Reality Check witness reacts to the target")
	_check(GossipSystem.share(witness, stranger), "witness can pass the Reality Check story")
	EventBus.dialogue_requested.emit(stranger.id)
	await get_tree().process_frame
	var rumor := _find_named_descendant(dialogue, "DialogueRumor")
	_check(rumor is Label and witness.display_name in str(rumor.text),
			"dialogue previews sourced gossip")
	_check(rumor is Label and not str(rumor.text).contains("misjudged you in public"),
			"dialogue phrases player memories from the player's view")
	dialogue.call("_do_action_with_roll", "chat")
	await get_tree().process_frame
	var result := _find_named_descendant(dialogue, "DialogueResult")
	_check(result is Label and witness.display_name in str(result.text),
			"stranger repeats sourced gossip in dialogue")
	dialogue._unhandled_input(_action("ui_cancel"))
	await get_tree().process_frame


func _prepare_social_playthrough_records(target: NPCRecord, witness: NPCRecord, stranger: NPCRecord) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	sheet.base_stats["STR"] = 13
	sheet.base_stats["CHA"] = 13
	sheet.skills["streetwise"] = 10.0
	sheet.skills["persuasion"] = 80.0
	sheet.flags["drunk_minutes"] = 60
	_place_social_playtest_records(target, witness, stranger)
	target.appearance_tags = ["plain"]
	target.relationships["player"] = 20.0
	target.flags.erase("dating_player")
	for stat in CharacterSheet.STAT_IDS:
		target.stats[stat] = 8
	target.stats["STR"] = 15
	target.personality["bravery"] = 50
	witness.memories.clear()
	stranger.memories.clear()
	witness.relationships[stranger.id] = 45.0
	stranger.relationships[witness.id] = 45.0


func _place_social_playtest_records(target: NPCRecord, witness: NPCRecord, stranger: NPCRecord) -> void:
	var scene_id := "loc_social_playtest"
	for npc in [target, witness]:
		npc.current_location_id = scene_id
		npc.current_activity = "idle"
		npc.traveling = false
		npc.travel_to_id = ""
	stranger.current_location_id = "loc_bar"
	stranger.current_activity = "idle"
	stranger.traveling = false
	stranger.travel_to_id = ""


func _dialogue_result_has_text(dialogue: Node) -> bool:
	var result := _find_named_descendant(dialogue, "DialogueResult")
	return result is Label and str(result.text).strip_edges() != ""


func _find_named_descendant(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_named_descendant(child, node_name)
		if found != null:
			return found
	return null


func _survival_feedback_kind() -> String:
	var feedback := _main.get_node_or_null("SurvivalFeedback")
	return str(feedback.get_meta("last_survival_kind", "")) if feedback != null else ""


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


func _descendant_text_contains_all(node: Node, pieces: Array[String]) -> bool:
	var value = node.get("text")
	if value != null:
		var text := str(value)
		var has_all := true
		for piece in pieces:
			has_all = has_all and text.contains(piece)
		if has_all:
			return true
	for child in node.get_children():
		if _descendant_text_contains_all(child, pieces):
			return true
	return false


func _exterior_facade_count() -> int:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return 0
	var layer := world_root.get_child(0).get_node_or_null("FacadeLayer")
	return layer.get_child_count() if layer != null else 0


func _exterior_street_prop_count() -> int:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return 0
	var layer := world_root.get_child(0).get_node_or_null("StreetPropLayer")
	return layer.get_child_count() if layer != null else 0


func _exterior_ground_tile_count(tile: Vector2i) -> int:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return 0
	var world = world_root.get_child(0)
	var layer: TileMapLayer = world.get("ground")
	if layer == null:
		return 0
	var count := 0
	for cell in layer.get_used_cells():
		if layer.get_cell_atlas_coords(cell) == tile:
			count += 1
	return count


func _find_current_world_node_with_property(property_name: String) -> Node:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return null
	for child in world_root.get_child(0).get_children():
		if child.get(property_name) != null:
			return child
	return null


func _current_world_named_count(node_name: String) -> int:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return 0
	return _count_named_descendants(world_root.get_child(0), node_name)


func _move_player_to_current_world_cell(cell: Vector2i) -> void:
	var world_root: Node = _main.get_node("WorldRoot")
	if world_root.get_child_count() == 0:
		return
	var world := world_root.get_child(0)
	if world.has_method("cell_to_world"):
		_player.set("global_position", world.call("cell_to_world", cell))
		_reset_player_camera_smoothing()


func _reset_player_camera_smoothing() -> void:
	var camera := _player.get_node_or_null("Camera2D")
	if camera != null and camera.has_method("reset_smoothing"):
		camera.call("reset_smoothing")


func _count_named_descendants(node: Node, node_name: String) -> int:
	var count := 1 if node.name == node_name else 0
	for child in node.get_children():
		count += _count_named_descendants(child, node_name)
	return count


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


func _report() -> void:
	_verify_output_dir_matches_run()
	print("[Playtest screenshots]")
	for shot in _shots:
		print("  %s" % shot)
	print("Playtest driver: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))


func _verify_output_dir_matches_run() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var expected := {}
	for shot in _shots:
		expected[str(shot).get_file()] = true
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		_check(false, "playtest output directory opens for review")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png" \
				and not expected.has(file_name):
			_check(false, "playtest output has no stale screenshot %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
