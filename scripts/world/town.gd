extends TileWorld
## The town exterior — stamped procedurally (grass field, roads, building
## shells with doors) so layout changes are code tweaks, not pixel art.
## Registers every door position into the Locations registry; the abstract
## NPC sim navigates by those points.

const W := 62
const H := 34

var player_spawn: Vector2

## Buildings: rect (in cells), door cell, location id, label.
const BUILDINGS := [
	{"rect": Rect2i(3, 2, 14, 7), "door": Vector2i(9, 8), "id": "loc_diner", "label": "Mel's Diner"},
	{"rect": Rect2i(24, 2, 12, 6), "door": Vector2i(29, 7), "id": "loc_store", "label": "QuikStop"},
	{"rect": Rect2i(44, 2, 15, 8), "door": Vector2i(50, 9), "id": "loc_offices", "label": "Vantage Plaza"},
	{"rect": Rect2i(3, 15, 12, 6), "door": Vector2i(8, 15), "id": "loc_bar", "label": "The Rusty Anchor"},
	{"rect": Rect2i(24, 15, 16, 10), "door": Vector2i(31, 15), "id": "loc_bricks", "label": "The Bricks"},
	{"rect": Rect2i(44, 15, 14, 7), "door": Vector2i(50, 15), "id": "loc_site", "label": "Site 9 (keep out)"},
	{"rect": Rect2i(3, 29, 16, 4), "door": Vector2i(10, 29), "id": "loc_rowhouse_a", "label": "Rowhouses East"},
	{"rect": Rect2i(30, 29, 16, 4), "door": Vector2i(37, 29), "id": "loc_rowhouse_b", "label": "Rowhouses West"},
]


func _ready() -> void:
	# Grass field.
	for x in W:
		for y in H:
			set_ground(Vector2i(x, y), GRASS)
	# Roads: two horizontal, one vertical spine.
	for x in W:
		for y in [11, 12, 26, 27]:
			set_ground(Vector2i(x, y), ROAD)
	for y in H:
		for x in [20, 21]:
			set_ground(Vector2i(x, y), ROAD)
	# Buildings.
	for b in BUILDINGS:
		_stamp_building(b.rect, b.door, b.id, b.label)
	# Street parking: the carjack gamble, distributed around town.
	for cell in [Vector2i(8, 13), Vector2i(27, 13), Vector2i(40, 10),
			Vector2i(54, 13), Vector2i(12, 28), Vector2i(48, 25)]:
		var car := ParkedCar.new()
		car.position = cell_to_world(cell)
		add_child(car)
	player_spawn = cell_to_world(Vector2i(22, 13))
	Locations.register_door("exterior", player_spawn)


func _stamp_building(rect: Rect2i, door_cell: Vector2i, loc_id: String, label: String) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			var edge: bool = x == rect.position.x or x == rect.end.x - 1 \
					or y == rect.position.y or y == rect.end.y - 1
			if edge:
				set_wall(cell)
			else:
				set_ground(cell, FLOOR)
	place_door(door_cell, loc_id, label)
	# Door position registered one tile OUTSIDE the wall so NPC paths end
	# on walkable ground.
	var outside := door_cell + (Vector2i(0, 1) if door_cell.y == rect.end.y - 1 else Vector2i(0, -1))
	Locations.register_door(loc_id, cell_to_world(outside))


## A random spot on the road network — wander anchors for exterior NPCs.
func random_exterior_point(rng: RandomNumberGenerator) -> Vector2:
	if rng.randf() < 0.5:
		return cell_to_world(Vector2i(rng.randi_range(1, W - 2), [11, 12, 26, 27].pick_random()))
	return cell_to_world(Vector2i([20, 21].pick_random(), rng.randi_range(1, H - 2)))
