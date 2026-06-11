extends Node2D
## Root scene: wires the town, player, lighting, and HUD together.

@onready var town: Node2D = $Town
@onready var player: Player = $Player


func _ready() -> void:
	player.global_position = town.player_spawn


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameFlow.to_main_menu()
