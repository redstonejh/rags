class_name Interior
extends TileWorld
## An enterable building interior, built from a small ASCII map.
## Legend: 'w' wall · 'f' floor · 'X' exit door · 'F' fridge ·
##         'C' counter (solid) · 's' NPC spawn spot
## The player's location_id is set by Main when entering.

@export var location_id: String = ""

var entry_point: Vector2
var npc_spawn_points: Array[Vector2] = []

const MAPS := {
	"loc_diner": [
		"wwwwwwwwwwwwww",
		"wfsffffffffsfw",
		"wffffffffffffw",
		"wCCCCCCffffffw",
		"wfsfffffsffffw",
		"wffffFffffffsw",
		"wffffffffffffw",
		"wwwwwwXwwwwwww",
	],
	"loc_store": [
		"wwwwwwwwwwww",
		"wfsfffffsffw",
		"wfCCffCCfffw",
		"wffffffffffw",
		"wfCCffCCfsfw",
		"wffffffffffw",
		"wwwwwXwwwwww",
	],
	"loc_bricks": [
		"wwwwwwwwwwwwww",
		"wfsffffffffsfw",
		"wffffffffffffw",
		"wffwwffwwffffw",
		"wfsfffffffsffw",
		"wfFffffffffffw",
		"wwwwwwwXwwwwww",
	],
}


func _ready() -> void:
	var map: Array = MAPS.get(location_id, MAPS["loc_diner"])
	var fridge_scene: PackedScene = load("res://scenes/props/Fridge.tscn")
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"w":
					set_wall(cell)
				"f":
					set_ground(cell, FLOOR)
				"s":
					set_ground(cell, FLOOR)
					npc_spawn_points.append(cell_to_world(cell))
				"C":
					set_wall(cell) # counters are solid placeholder walls
				"F":
					set_ground(cell, FLOOR)
					var fridge := fridge_scene.instantiate()
					fridge.position = cell_to_world(cell)
					add_child(fridge)
				"X":
					place_door(cell, "exterior", "Leave")
					entry_point = cell_to_world(cell + Vector2i(0, -1))
	if npc_spawn_points.is_empty():
		npc_spawn_points.append(entry_point)
