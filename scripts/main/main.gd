extends Node2D
## Root gameplay scene. Owns the current world (exterior or an interior),
## swaps it on door travel, and wires the SimEngine's embodiment hooks.

const TOWN_SCENE := preload("res://scenes/world/Town.tscn")
const REALITY_STING_PATH := "res://assets/audio/reality_check.wav"
const REALITY_CAMERA_ZOOM_MULT := 1.12
const REALITY_CAMERA_OFFSET_MAX := 36.0
const REALITY_CAMERA_IN_TIME := 0.08
const REALITY_CAMERA_HOLD_TIME := 0.10
const REALITY_CAMERA_OUT_TIME := 0.22

var current_world: Node2D = null
var _reality_camera_tween: Tween = null
var _reality_sting_player: AudioStreamPlayer = null

@onready var world_root: Node2D = $WorldRoot
@onready var player: Player = $Player
@onready var ui_stack: CanvasLayer = $UIStack


func _ready() -> void:
	WorldState.ensure_player_sheet()
	_setup_reality_check_audio()
	EventBus.travel_requested.connect(_travel_to)
	EventBus.player_died.connect(_on_player_died)
	EventBus.reality_check.connect(_on_reality_check)
	SimEngine.player_node = player
	# Resume wherever the save says the player was; new games start outside.
	_enter_location(WorldState.player_location_id, true)
	_show_opening_beat.call_deferred()


func _exit_tree() -> void:
	if _reality_sting_player != null:
		_reality_sting_player.stop()
		_reality_sting_player.stream = null
	SimEngine.spawn_host = null
	SimEngine.player_node = null


func _travel_to(location_id: String) -> void:
	_enter_location(location_id, false)


func _enter_location(location_id: String, initial: bool) -> void:
	var came_from := WorldState.player_location_id
	if current_world != null:
		SimEngine.spawn_host = null
		current_world.queue_free()
		current_world = null

	WorldState.player_location_id = location_id
	EventBus.player_location_changed.emit(location_id)

	if location_id == "exterior" or not Locations.is_interior(location_id):
		WorldState.player_location_id = "exterior"
		current_world = TOWN_SCENE.instantiate()
		world_root.add_child(current_world)
		if initial:
			player.global_position = _initial_exterior_spawn(location_id)
		else:
			# Step out of the building we just left.
			player.global_position = Locations.door_pos(came_from) \
					if came_from != "exterior" else current_world.player_spawn
	else:
		var interior := Interior.new()
		interior.location_id = location_id
		current_world = interior
		world_root.add_child(current_world)
		player.global_position = interior.entry_point

	SimEngine.spawn_host = current_world
	_apply_camera_limits()


func _apply_camera_limits() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	if WorldState.player_location_id != "exterior" or current_world == null:
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		return
	var ground: TileMapLayer = current_world.get("ground")
	if ground == null:
		return
	var used := ground.get_used_rect()
	camera.limit_left = used.position.x * TileWorld.TILE
	camera.limit_top = used.position.y * TileWorld.TILE
	camera.limit_right = (used.position.x + used.size.x) * TileWorld.TILE
	camera.limit_bottom = (used.position.y + used.size.y) * TileWorld.TILE
	if camera.has_method("reset_smoothing"):
		camera.reset_smoothing()


func _initial_exterior_spawn(requested_location_id: String) -> Vector2:
	var marker_id := requested_location_id
	var sheet := WorldState.player_sheet
	if (marker_id == "" or marker_id == "exterior") and sheet != null:
		marker_id = str(sheet.flags.get("start_location_id", ""))
	var marker_pos := Locations.door_pos(marker_id)
	return marker_pos if marker_pos != Vector2.ZERO else current_world.player_spawn


func _show_opening_beat() -> void:
	var sheet := WorldState.player_sheet
	if sheet == null or not sheet.alive:
		return
	var life_number := int(sheet.lives_lived)
	if int(sheet.flags.get("opening_seen_life", 0)) == life_number:
		return
	sheet.flags["opening_seen_life"] = life_number
	var origin := ContentDB.get_origin(sheet.origin_id)
	var origin_name := origin.display_name if origin else "This life"
	var start_name := Locations.display_name(str(sheet.flags.get("start_location_id", "exterior")))
	EventBus.toast.emit("%s begins at %s. Check the HUD objective; rent, food, and work do not wait." % [
			origin_name, start_name])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		ui_stack.call("toggle_pause_menu")
		get_viewport().set_input_as_handled()


# -------------------------------------------------------- Reality Check

func _on_reality_check(_perceived: float, _actual: float, npc_id: String) -> void:
	_play_reality_check_sting(npc_id)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var base_zoom := _camera_base_zoom(camera)
	var base_offset := _camera_base_offset(camera)
	if _reality_camera_tween != null:
		_reality_camera_tween.kill()
	_reality_camera_tween = create_tween()
	_reality_camera_tween.set_trans(Tween.TRANS_QUAD)
	_reality_camera_tween.set_ease(Tween.EASE_OUT)

	var pulse_count := int(camera.get_meta("reality_check_pulses", 0)) + 1
	camera.set_meta("reality_check_pulses", pulse_count)
	camera.set_meta("last_reality_check_target", npc_id)

	var focus_offset := _reality_camera_focus_offset(npc_id)
	camera.zoom = base_zoom
	camera.offset = base_offset
	_reality_camera_tween.tween_property(camera, "zoom",
			base_zoom * REALITY_CAMERA_ZOOM_MULT, REALITY_CAMERA_IN_TIME)
	_reality_camera_tween.parallel().tween_property(camera, "offset",
			base_offset + focus_offset, REALITY_CAMERA_IN_TIME)
	_reality_camera_tween.tween_interval(REALITY_CAMERA_HOLD_TIME)
	_reality_camera_tween.tween_property(camera, "zoom", base_zoom, REALITY_CAMERA_OUT_TIME)
	_reality_camera_tween.parallel().tween_property(camera, "offset",
			base_offset, REALITY_CAMERA_OUT_TIME)


func _camera_base_zoom(camera: Camera2D) -> Vector2:
	if not camera.has_meta("reality_check_base_zoom"):
		camera.set_meta("reality_check_base_zoom", camera.zoom)
	return camera.get_meta("reality_check_base_zoom") as Vector2


func _camera_base_offset(camera: Camera2D) -> Vector2:
	if not camera.has_meta("reality_check_base_offset"):
		camera.set_meta("reality_check_base_offset", camera.offset)
	return camera.get_meta("reality_check_base_offset") as Vector2


func _reality_camera_focus_offset(npc_id: String) -> Vector2:
	var npc: NPCRecord = WorldState.npcs.get(npc_id)
	if npc == null or npc.agent == null or not is_instance_valid(npc.agent):
		return Vector2.ZERO
	var to_target: Vector2 = npc.agent.global_position - player.global_position
	if to_target.length_squared() <= 1.0:
		return Vector2.ZERO
	return to_target.limit_length(REALITY_CAMERA_OFFSET_MAX)


func _setup_reality_check_audio() -> void:
	_reality_sting_player = AudioStreamPlayer.new()
	_reality_sting_player.name = "RealityCheckSting"
	_reality_sting_player.stream = load(REALITY_STING_PATH)
	_reality_sting_player.volume_db = -8.0
	add_child(_reality_sting_player)


func _play_reality_check_sting(npc_id: String) -> void:
	if _reality_sting_player == null:
		return
	_reality_sting_player.set_meta("reality_check_stings",
			int(_reality_sting_player.get_meta("reality_check_stings", 0)) + 1)
	_reality_sting_player.set_meta("last_reality_check_target", npc_id)
	_reality_sting_player.stop()
	if DisplayServer.get_name() != "headless":
		_reality_sting_player.play()


# ---------------------------------------------------------------- death

const DEATH_LINES := {
	"starvation": "Starved. The dollar menu was right there.",
}
const DEATH_MODAL_ID := "death_screen"

var _death_screen: CanvasLayer = null


## Permadeath, but the world persists: the screen offers exactly one path
## forward — a new life in the same town.
func _on_player_died(cause: String) -> void:
	if _death_screen != null:
		return
	GameClock.push_pause_lock(DEATH_MODAL_ID)

	_death_screen = CanvasLayer.new()
	_death_screen.layer = 50
	add_child(_death_screen)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_screen.add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-260, -110)
	vbox.custom_minimum_size = Vector2(520, 0)
	vbox.add_theme_constant_override("separation", 16)
	_death_screen.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
	vbox.add_child(title)

	var cause_label := Label.new()
	cause_label.text = DEATH_LINES.get(cause, "Cause of death: %s." % cause)
	cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cause_label)

	# Your obituary, as the Gazette will run it. Your next character can read it.
	if not WorldState.obituaries.is_empty():
		var obit := Label.new()
		obit.text = "— THE RUST HARBOR GAZETTE —\n%s" % str(WorldState.obituaries.back())
		obit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obit.add_theme_font_size_override("font_size", 12)
		obit.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
		vbox.add_child(obit)

	var epitaph := Label.new()
	epitaph.text = "The town continues without you."
	epitaph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epitaph.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(epitaph)

	var button := Button.new()
	button.text = "Continue (as someone new)"
	button.custom_minimum_size = Vector2(240, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		GameClock.release_pause_lock(DEATH_MODAL_ID)
		GameFlow.to_character_creation())
	vbox.add_child(button)

	# Generational play: a grown child can take over the house and the grudges.
	for kid in Body.heir_candidates(WorldState.player_sheet):
		var heir_btn := Button.new()
		heir_btn.text = "Continue as %s (your kid — inherits everything)" % str(kid.get("name", "?"))
		heir_btn.custom_minimum_size = Vector2(240, 40)
		heir_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		heir_btn.pressed.connect(func() -> void:
			GameClock.release_pause_lock(DEATH_MODAL_ID)
			GameFlow.continue_as_heir(kid))
		vbox.add_child(heir_btn)
