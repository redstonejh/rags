extends Node2D
## Root gameplay scene. Owns the current world (exterior or an interior),
## swaps it on door travel, and wires the SimEngine's embodiment hooks.

const TOWN_SCENE := preload("res://scenes/world/Town.tscn")

var current_world: Node2D = null

@onready var world_root: Node2D = $WorldRoot
@onready var player: Player = $Player


func _ready() -> void:
	WorldState.ensure_player_sheet()
	EventBus.travel_requested.connect(_travel_to)
	EventBus.player_died.connect(_on_player_died)
	SimEngine.player_node = player
	# Resume wherever the save says the player was; new games start outside.
	_enter_location(WorldState.player_location_id, true)


func _exit_tree() -> void:
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
			player.global_position = current_world.player_spawn
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameFlow.to_main_menu()


# ---------------------------------------------------------------- death

const DEATH_LINES := {
	"starvation": "Starved. The dollar menu was right there.",
}

var _death_screen: CanvasLayer = null


## Permadeath, but the world persists: the screen offers exactly one path
## forward — a new life in the same town.
func _on_player_died(cause: String) -> void:
	if _death_screen != null:
		return
	GameClock.paused = true
	EventBus.time_scale_changed.emit(0.0)

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
		GameClock.paused = false
		EventBus.time_scale_changed.emit(GameClock.time_scale)
		GameFlow.to_character_creation())
	vbox.add_child(button)
