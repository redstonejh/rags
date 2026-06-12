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
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var sheet := CharacterSheet.new()
	sheet.char_name = "Harness Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	_seed_people_app_state()
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)


func _seed_people_app_state() -> void:
	var people: Array = WorldState.npcs.values()
	if people.size() < 2:
		_check(false, "people app seed has enough NPCs")
		return
	var date: NPCRecord = people[0]
	var rival: NPCRecord = people[1]
	date.relationships["player"] = 62.0
	date.relationships[rival.id] = -45.0
	date.flags["dating_player"] = true
	date.add_memory("date", "player", "said yes to a date with you", 1.0, 7.0)
	rival.relationships["player"] = -38.0
	rival.relationships[date.id] = -45.0
	rival.add_memory("witnessed", "player", "were seen arguing outside Mel's", -0.4, 5.0, true)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player")
	_check(_player_has_walk_sheets(), "player uses layered walk sheets")
	await _verify_player_outfit_switch()
	await _verify_dialogue_portrait()
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
	_check(_descendant_text_contains(people_content, "dating you"), "People tab shows dating status")
	_check(_descendant_text_contains(people_content, "Gossip:"), "People tab shows gossip")


func _close_phone_open_inventory() -> void:
	var phone: CanvasLayer = _main.get_node("Phone")
	var inventory: CanvasLayer = _main.get_node("Inventory")
	phone._unhandled_input(_action("phone"))
	inventory._unhandled_input(_action("inventory"))
	await get_tree().process_frame
	_check(not phone.visible and inventory.visible and GameClock.paused, "inventory opened after phone")


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


func _verify_dialogue_portrait() -> void:
	var npc: NPCRecord = WorldState.npcs.values().front()
	EventBus.dialogue_requested.emit(npc.id)
	await get_tree().process_frame
	var dialogue: CanvasLayer = _main.get_node("Dialogue")
	var portrait := _find_named_descendant(dialogue, "Portrait")
	_check(dialogue.visible and portrait is TextureRect and portrait.texture != null,
			"dialogue opens with NPC portrait")
	await _checkpoint("00_dialogue")
	dialogue._unhandled_input(_action("ui_cancel"))
	await get_tree().process_frame


func _find_named_descendant(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_named_descendant(child, node_name)
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
	print("[Playtest screenshots]")
	for shot in _shots:
		print("  %s" % shot)
	print("Playtest driver: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
