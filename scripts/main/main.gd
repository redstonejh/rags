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
