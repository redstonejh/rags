extends TileWorld
## The town exterior — stamped procedurally (grass field, roads, building
## shells with doors) so layout changes are code tweaks, not pixel art.
## Registers every door position into the Locations registry; the abstract
## NPC sim navigates by those points.

const W := 62
const H := 34
const BUILDING_ASSET_DIR := "res://assets/buildings/"
const ROOF_TEXTURE_PATH := BUILDING_ASSET_DIR + "roof_tile.png"
const FACADE_PLAIN_TEXTURE_PATH := BUILDING_ASSET_DIR + "facade_plain.png"
const FACADE_WINDOW_LIT_TEXTURE_PATH := BUILDING_ASSET_DIR + "facade_window_lit.png"
const FACADE_WINDOW_DARK_TEXTURE_PATH := BUILDING_ASSET_DIR + "facade_window_dark.png"
const AWNING_RED_TEXTURE_PATH := BUILDING_ASSET_DIR + "awning_red.png"
const AWNING_GREEN_TEXTURE_PATH := BUILDING_ASSET_DIR + "awning_green.png"
const SIGN_TEXTURES := {
	"loc_diner": BUILDING_ASSET_DIR + "sign_loc_diner.png",
	"loc_store": BUILDING_ASSET_DIR + "sign_loc_store.png",
	"loc_offices": BUILDING_ASSET_DIR + "sign_loc_offices.png",
	"loc_bar": BUILDING_ASSET_DIR + "sign_loc_bar.png",
	"loc_bricks": BUILDING_ASSET_DIR + "sign_loc_bricks.png",
	"loc_site": BUILDING_ASSET_DIR + "sign_loc_site.png",
	"loc_rowhouse_a": BUILDING_ASSET_DIR + "sign_loc_rowhouse_a.png",
	"loc_rowhouse_b": BUILDING_ASSET_DIR + "sign_loc_rowhouse_b.png",
}
const AWNING_TEXTURES := {
	"loc_diner": AWNING_RED_TEXTURE_PATH,
	"loc_store": AWNING_GREEN_TEXTURE_PATH,
	"loc_bar": AWNING_RED_TEXTURE_PATH,
}
const STREET_LAMP_TEXTURE_PATH := "res://assets/props/street_lamp.png"
const TRASH_CAN_TEXTURE_PATH := "res://assets/props/trash_can.png"
const DUMPSTER_TEXTURE_PATH := "res://assets/props/dumpster.png"
const NEWS_BOX_TEXTURE_PATH := "res://assets/props/news_box.png"
const BUS_STOP_TEXTURE_PATH := "res://assets/props/bus_stop.png"
const STREET_CAMP_TEXTURE_PATH := "res://assets/props/street_camp.png"
const APARTMENT_SIGN_TEXTURE_PATH := "res://assets/props/apartment_sign.png"
const ROOF_FADE_ALPHA := 0.38
const ROOF_FADE_SPEED := 10.0

var player_spawn: Vector2
var facade_layer: Node2D = null
var street_prop_layer: Node2D = null
var roof_groups: Array[Dictionary] = []

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
	roof_groups.clear()
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
	_stamp_sidewalks()
	_stamp_dirt_lots()
	facade_layer = Node2D.new()
	facade_layer.name = "FacadeLayer"
	add_child(facade_layer)
	street_prop_layer = Node2D.new()
	street_prop_layer.name = "StreetPropLayer"
	add_child(street_prop_layer)
	# Buildings.
	for b in BUILDINGS:
		_stamp_building(b.rect, b.door, b.id, b.label)
	# Street parking: the carjack gamble, distributed around town.
	for cell in [Vector2i(8, 13), Vector2i(27, 13), Vector2i(40, 10),
			Vector2i(54, 13), Vector2i(12, 28), Vector2i(48, 25)]:
		var car := ParkedCar.new()
		car.position = cell_to_world(cell)
		add_child(car)
	_place_street_props()
	player_spawn = cell_to_world(Vector2i(22, 13))
	Locations.register_door("exterior", player_spawn)
	Locations.register_door("loc_bus_stop", cell_to_world(Vector2i(12, 12)))
	Locations.register_door("loc_gas_station_rear", cell_to_world(Vector2i(5, 24)))
	Locations.register_door("loc_decent_apartment", cell_to_world(Vector2i(37, 28)))


func _process(delta: float) -> void:
	_update_roof_fades(delta)


func _stamp_sidewalks() -> void:
	for x in W:
		for y in [10, 13, 25, 28]:
			_set_ground_if_grass(Vector2i(x, y), SIDEWALK)
	for y in H:
		for x in [19, 22]:
			_set_ground_if_grass(Vector2i(x, y), SIDEWALK)
	for b in BUILDINGS:
		var door_cell: Vector2i = b.door
		var front_dir := Vector2i(0, 1) if door_cell.y == b.rect.end.y - 1 else Vector2i(0, -1)
		for dx in range(-2, 3):
			_set_ground_if_grass(door_cell + front_dir + Vector2i(dx, 0), SIDEWALK)


func _stamp_dirt_lots() -> void:
	for x in range(42, 60):
		for y in range(22, 26):
			_set_ground_if_grass(Vector2i(x, y), DIRT)
	for x in range(4, 17):
		for y in range(22, 25):
			_set_ground_if_grass(Vector2i(x, y), DIRT)
	for cell in [Vector2i(55, 24), Vector2i(56, 24), Vector2i(5, 24), Vector2i(6, 24)]:
		_set_ground_if_grass(cell, DIRT)


func _set_ground_if_grass(cell: Vector2i, tile: Vector2i) -> void:
	if cell.x < 0 or cell.x >= W or cell.y < 0 or cell.y >= H:
		return
	if ground.get_cell_atlas_coords(cell) == GRASS:
		set_ground(cell, tile)


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
	_add_facade(rect, door_cell, loc_id)
	place_door(door_cell, loc_id, label)
	# Door position registered one tile OUTSIDE the wall so NPC paths end
	# on walkable ground.
	var outside := door_cell + (Vector2i(0, 1) if door_cell.y == rect.end.y - 1 else Vector2i(0, -1))
	Locations.register_door(loc_id, cell_to_world(outside))


func _add_facade(rect: Rect2i, door_cell: Vector2i, loc_id: String) -> void:
	if facade_layer == null:
		return
	var roof_sprites: Array[Sprite2D] = []
	for x in range(rect.position.x, rect.end.x):
		var roof := _add_facade_sprite(ROOF_TEXTURE_PATH, Vector2i(x, rect.position.y), Vector2(0, -20))
		if roof != null:
			roof.name = "RoofSprite"
			roof_sprites.append(roof)
	if not roof_sprites.is_empty():
		roof_groups.append({
			"rect": rect,
			"sprites": roof_sprites,
		})
	var face_y := door_cell.y
	for x in range(rect.position.x, rect.end.x):
		var cell := Vector2i(x, face_y)
		if cell == door_cell:
			continue
		var front_index := x - rect.position.x
		var texture_path := FACADE_PLAIN_TEXTURE_PATH
		if front_index % 3 == 1:
			texture_path = FACADE_WINDOW_LIT_TEXTURE_PATH \
					if loc_id in ["loc_diner", "loc_store", "loc_bar"] \
					else FACADE_WINDOW_DARK_TEXTURE_PATH
		_add_facade_sprite(texture_path, cell, Vector2(0, -8))
	if AWNING_TEXTURES.has(loc_id):
		_add_facade_sprite(AWNING_TEXTURES[loc_id], door_cell, Vector2(0, -16))
	if SIGN_TEXTURES.has(loc_id):
		_add_facade_sprite(SIGN_TEXTURES[loc_id], door_cell, Vector2(0, -42))


func _add_facade_sprite(texture_path: String, cell: Vector2i, offset: Vector2) -> Sprite2D:
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.position = cell_to_world(cell) + offset
	facade_layer.add_child(sprite)
	return sprite


func _update_roof_fades(delta: float) -> void:
	var player: Node2D = SimEngine.player_node
	if player == null or not is_instance_valid(player):
		return
	var player_cell := ground.local_to_map(to_local(player.global_position))
	for group in roof_groups:
		var rect: Rect2i = group.get("rect", Rect2i())
		var target_alpha := ROOF_FADE_ALPHA if _cell_is_behind_roof(player_cell, rect) else 1.0
		var sprites: Array = group.get("sprites", [])
		for sprite in sprites:
			if sprite is Sprite2D:
				var current_alpha: float = sprite.modulate.a
				sprite.modulate.a = lerpf(current_alpha, target_alpha,
						clampf(delta * ROOF_FADE_SPEED, 0.0, 1.0))


func _cell_is_behind_roof(cell: Vector2i, rect: Rect2i) -> bool:
	if cell.x < rect.position.x or cell.x >= rect.end.x:
		return false
	return cell.y >= rect.position.y - 1 and cell.y <= rect.position.y + 1


func _place_street_props() -> void:
	var props := [
		{"path": STREET_LAMP_TEXTURE_PATH, "cell": Vector2i(18, 10), "offset": Vector2(0, -18)},
		{"path": STREET_LAMP_TEXTURE_PATH, "cell": Vector2i(23, 13), "offset": Vector2(0, -18)},
		{"path": STREET_LAMP_TEXTURE_PATH, "cell": Vector2i(43, 10), "offset": Vector2(0, -18)},
		{"path": STREET_LAMP_TEXTURE_PATH, "cell": Vector2i(22, 25), "offset": Vector2(0, -18)},
		{"path": STREET_LAMP_TEXTURE_PATH, "cell": Vector2i(43, 25), "offset": Vector2(0, -18)},
		{"path": TRASH_CAN_TEXTURE_PATH, "cell": Vector2i(17, 10), "offset": Vector2.ZERO},
		{"path": TRASH_CAN_TEXTURE_PATH, "cell": Vector2i(36, 9), "offset": Vector2.ZERO},
		{"path": TRASH_CAN_TEXTURE_PATH, "cell": Vector2i(46, 23), "offset": Vector2.ZERO},
		{"path": DUMPSTER_TEXTURE_PATH, "cell": Vector2i(55, 24), "offset": Vector2(8, -2)},
		{"path": DUMPSTER_TEXTURE_PATH, "cell": Vector2i(5, 24), "offset": Vector2(8, -2)},
		{"path": NEWS_BOX_TEXTURE_PATH, "cell": Vector2i(13, 10), "offset": Vector2.ZERO},
		{"path": NEWS_BOX_TEXTURE_PATH, "cell": Vector2i(25, 14), "offset": Vector2.ZERO},
		{"path": BUS_STOP_TEXTURE_PATH, "cell": Vector2i(11, 10), "offset": Vector2(0, -7), "name": "BusStopSprite"},
		{"path": STREET_CAMP_TEXTURE_PATH, "cell": Vector2i(8, 24), "offset": Vector2(0, -4), "name": "StreetCampSprite"},
		{"path": APARTMENT_SIGN_TEXTURE_PATH, "cell": Vector2i(37, 28), "offset": Vector2(0, -10), "name": "ApartmentSignSprite"},
	]
	for prop in props:
		_add_street_prop(prop.path, prop.cell, prop.offset, prop.get("name", "StreetProp"))
	for cell in [Vector2i(15, 13), Vector2i(33, 13), Vector2i(25, 25), Vector2i(52, 28)]:
		var bench := Amenity.new()
		bench.configure("bench", 1.0, "the bench", "Sleep on", Color(0.45, 0.3, 0.2))
		bench.position = cell_to_world(cell)
		add_child(bench)


func _add_street_prop(texture_path: String, cell: Vector2i, offset: Vector2,
		node_name: String = "StreetProp") -> void:
	if street_prop_layer == null:
		return
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.position = cell_to_world(cell) + offset
	street_prop_layer.add_child(sprite)


## A random spot on the road network — wander anchors for exterior NPCs.
func random_exterior_point(rng: RandomNumberGenerator) -> Vector2:
	if rng.randf() < 0.5:
		return cell_to_world(Vector2i(rng.randi_range(1, W - 2), [11, 12, 26, 27].pick_random()))
	return cell_to_world(Vector2i([20, 21].pick_random(), rng.randi_range(1, H - 2)))
