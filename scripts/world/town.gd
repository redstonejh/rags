extends Node2D
## Builds the placeholder town at runtime from an ASCII map.
##
## M0 placeholder approach: the TileSet (a 4-tile colored atlas) and both
## TileMapLayers are generated in code so the project needs zero art assets.
## When real tile art exists, only _build_tileset() and the legend change —
## the map/collision/spawn logic stays.

const TILE := 32

# Atlas coords in the generated tileset texture.
const GRASS := Vector2i(0, 0)
const ROAD := Vector2i(1, 0)
const FLOOR := Vector2i(2, 0)
const WALL := Vector2i(3, 0)

## Legend: '.' grass  '#' road  'w' wall  'f' floor  'D' doorway (floor)
##         'F' floor + fridge   'P' player spawn (grass)
const MAP: Array[String] = [
	"............................................",
	"............................................",
	"..wwwwwwwwww................wwwwwwwwww......",
	"..wffffffffw................wffffffffw......",
	"..wfFffffffw................wffffffffw......",
	"..wffffffffw................wffffffffw......",
	"..wffffffffw................wffffffffw......",
	"..wwwwwDwwww................wwwwwDwwww......",
	".......#........................#...........",
	".......#........................#...........",
	"##########################################..",
	".......#........................#...........",
	".......#........................#...........",
	".......#.........P..............#...........",
	".......#........................#...........",
	".......#........................#...........",
	"##########################################..",
	".......#........................#...........",
	".......#........................#...........",
	"............................................",
]

var player_spawn: Vector2 = Vector2.ZERO

var _ground: TileMapLayer
var _walls: TileMapLayer


func _ready() -> void:
	var tileset := _build_tileset()

	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = tileset
	add_child(_ground)

	_walls = TileMapLayer.new()
	_walls.name = "Walls"
	_walls.tile_set = tileset
	add_child(_walls)

	_fill_from_map()


func _fill_from_map() -> void:
	var fridge_scene: PackedScene = load("res://scenes/props/Fridge.tscn")
	for y in MAP.size():
		var row := MAP[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				".":
					_ground.set_cell(cell, 0, GRASS)
				"#":
					_ground.set_cell(cell, 0, ROAD)
				"f", "D":
					_ground.set_cell(cell, 0, FLOOR)
				"w":
					_ground.set_cell(cell, 0, FLOOR)
					_walls.set_cell(cell, 0, WALL)
				"F":
					_ground.set_cell(cell, 0, FLOOR)
					var fridge := fridge_scene.instantiate()
					fridge.position = _ground.map_to_local(cell)
					add_child(fridge)
				"P":
					_ground.set_cell(cell, 0, GRASS)
					player_spawn = _ground.map_to_local(cell)


## A 4-tile atlas (grass, road, floor, wall) drawn pixel-by-pixel, with a
## full-square collision polygon on the wall tile.
func _build_tileset() -> TileSet:
	var img := Image.create(TILE * 4, TILE, false, Image.FORMAT_RGB8)
	var bases: Array[Color] = [
		Color(0.30, 0.46, 0.25), # grass
		Color(0.28, 0.28, 0.30), # road
		Color(0.55, 0.45, 0.34), # floor (wood)
		Color(0.42, 0.40, 0.45), # wall
	]
	for t in 4:
		for px in TILE:
			for py in TILE:
				var c: Color = bases[t]
				# Cheap texture: checker speckle + a darker tile border.
				if (px + py) % 2 == 0:
					c = c.darkened(0.06)
				if px == 0 or py == 0:
					c = c.darkened(0.18)
				img.set_pixel(t * TILE + px, py, c)
	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer(0)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	# The source must join the TileSet BEFORE tiles get collision data,
	# or the tiles won't know the set's physics layers exist.
	ts.add_source(src, 0)
	for t in 4:
		src.create_tile(Vector2i(t, 0))

	var wall_data := src.get_tile_data(WALL, 0)
	wall_data.add_collision_polygon(0)
	var half := TILE / 2.0
	wall_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	]))

	return ts
