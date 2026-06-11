extends Node2D
## Root scene: wires the town, player, lighting, and HUD together.

@onready var town: Node2D = $Town
@onready var player: Player = $Player


func _ready() -> void:
	player.global_position = town.player_spawn
