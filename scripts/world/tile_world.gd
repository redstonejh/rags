class_name TileWorld
extends Node2D
## Base class for tile-built places (the town exterior and interiors).
## Builds the shared placeholder tileset in code — ground layer, wall layer
## with collision, and navigation polygons on every walkable tile so
## NavigationAgent2D works everywhere without hand-baking.

const TILE := 32
const TERRAIN_ATLAS_PATH := "res://assets/tiles/terrain_atlas.png"

const GRASS := Vector2i(0, 0)
const ROAD := Vector2i(1, 0)
const FLOOR := Vector2i(2, 0)
const WALL := Vector2i(3, 0)
## Floor with NO navigation polygon — placed under walls so paths can't
## route through buildings.
const FLOOR_SOLID := Vector2i(4, 0)
const SIDEWALK := Vector2i(5, 0)
const DIRT := Vector2i(6, 0)
const TILE_COUNT := 7

var ground: TileMapLayer
var walls: TileMapLayer


func _enter_tree() -> void:
	var tileset := _build_tileset()
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	add_child(ground)
	walls = TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tileset
	add_child(walls)


func set_ground(cell: Vector2i, tile: Vector2i) -> void:
	ground.set_cell(cell, 0, tile)


func set_wall(cell: Vector2i) -> void:
	ground.set_cell(cell, 0, FLOOR_SOLID)
	walls.set_cell(cell, 0, WALL)


func clear_wall(cell: Vector2i) -> void:
	walls.erase_cell(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return ground.map_to_local(cell)


## Door = floor opening in a wall + an Interactable that requests travel.
func place_door(cell: Vector2i, target_location_id: String, label: String) -> void:
	clear_wall(cell)
	ground.set_cell(cell, 0, FLOOR)
	var door := Door.new()
	door.target_location_id = target_location_id
	door.display_name = label
	door.position = cell_to_world(cell)
	add_child(door)


func _build_tileset() -> TileSet:
	var tex: Texture2D = load(TERRAIN_ATLAS_PATH)
	if tex == null:
		tex = ImageTexture.create_from_image(_build_fallback_atlas())

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer(0)
	ts.add_navigation_layer(0)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for t in TILE_COUNT:
		src.create_tile(Vector2i(t, 0))

	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])

	# Walkable tiles get a navigation polygon; the wall gets collision.
	for t in [GRASS, ROAD, FLOOR, SIDEWALK, DIRT]:
		var td := src.get_tile_data(t, 0)
		var nav := NavigationPolygon.new()
		nav.vertices = square
		nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
		td.set_navigation_polygon(0, nav)

	var wall_td := src.get_tile_data(WALL, 0)
	wall_td.add_collision_polygon(0)
	wall_td.set_collision_polygon_points(0, 0, square)

	return ts


func _build_fallback_atlas() -> Image:
	var img := Image.create(TILE * TILE_COUNT, TILE, false, Image.FORMAT_RGB8)
	var bases: Array[Color] = [
		Color(0.30, 0.46, 0.25), # grass
		Color(0.28, 0.28, 0.30), # road
		Color(0.55, 0.45, 0.34), # floor (wood)
		Color(0.42, 0.40, 0.45), # wall
		Color(0.55, 0.45, 0.34), # floor under walls (no nav)
		Color(0.52, 0.52, 0.50), # sidewalk
		Color(0.46, 0.33, 0.21), # dirt
	]
	for t in TILE_COUNT:
		for px in TILE:
			for py in TILE:
				var c: Color = bases[t]
				if (px + py) % 2 == 0:
					c = c.darkened(0.06)
				if px == 0 or py == 0:
					c = c.darkened(0.18)
				img.set_pixel(t * TILE + px, py, c)
	return img
