class_name Interior
extends TileWorld
## An enterable building interior, built from a small ASCII map.
## Legend: 'w' wall · 'f' floor · 'X' exit door · 's' NPC spawn spot ·
##         'C' counter (solid) · 'F' fridge · 'W' work spot · 'R' records desk ·
##         'S' shop counter · 'B' bar counter · 'b' bed · 'h' shower · 'T' TV ·
##         'D' street dealer · 'G' the fence

@export var location_id: String = ""

var entry_point: Vector2
var npc_spawn_points: Array[Vector2] = []
var layout_id: String = ""

const MAPS := {
	"loc_diner": [
		"wwwwwwwwwwwwww",
		"wfsffffffffsfw",
		"wfffffffffffWw",
		"wCCCCCCffffffw",
		"wfsfffffsffffw",
		"wffffFffffffsw",
		"wffffffffffffw",
		"wwwwwwXwwwwwww",
	],
	"loc_store": [
		"wwwwwwwwwwww",
		"wfsfffffsfSw",
		"wfCCffCCfffw",
		"wffffffffffw",
		"wfCCffCCfsfw",
		"wfWffffffffw",
		"wwwwwXwwwwww",
	],
	"loc_bricks": [
		"wwwwwwwwwwwwww",
		"wfsffffffwbfhw",
		"wffffffffwfffw",
		"wffwwffwwwfTfw",
		"wfsffffffffffw",
		"wfFffffffffsfw",
		"wwwwwwwXwwwwww",
	],
	"loc_offices": [
		"wwwwwwwwwwwwwwww",
		"wfsffffwffffffRw",
		"wfWfWffwffffffsw",
		"wffffffwwwffwwww",
		"wfWfWffffffffsfw",
		"wfsffffffffffffw",
		"wwwwwwwXwwwwwwww",
	],
	"loc_site": [
		"wwwwwwwwwwwwww",
		"wfsffffffffGfw",
		"wfWffsffWffffw",
		"wffffffffffsfw",
		"wfffWffffffDfw",
		"wwwwwwXwwwwwww",
	],
	"loc_bar": [
		"wwwwwwwwwwww",
		"wfsffffffsfw",
		"wfCCCBCCfffw",
		"wffffffffsfw",
		"wfsfffffffTw",
		"wwwwwXwwwwww",
	],
	"loc_jail": [
		"wwwwwwwwwwwwwwww",
		"wbfwbfwfsffffffw",
		"wffwffwfCCCCfffw",
		"wffwffwfffffffsw",
		"wffwffwffffffffw",
		"wwwXwwwwwwwwwwww",
	],
}

const HOME_MAPS := {
	"shelter_cot": [
		"wwwwwwwwwwwwww",
		"wbsfbfsfbfsffw",
		"wffffffffffffw",
		"wffwwwwwwffffw",
		"wfhffffffffsfw",
		"wwwwwwXwwwwwww",
	],
	"weekly_motel": [
		"wwwwwwwwwwww",
		"wffffbffffhw",
		"wffffffffffw",
		"wffffTfffffw",
		"wfffFffffsfw",
		"wwwwwXwwwwww",
	],
	"bricks_unit": [
		"wwwwwwwwwwwwww",
		"wfsffffffwbfhw",
		"wffffffffwfffw",
		"wffwwffwwwfTfw",
		"wfsffffffffffw",
		"wfFffffffffsfw",
		"wwwwwwwXwwwwww",
	],
	"decent_apartment": [
		"wwwwwwwwwwwwwwww",
		"wfsfffffwbbfffhw",
		"wffffffwfffffffw",
		"wffFfffwwwfffTfw",
		"wffffffffffffffw",
		"wfsffffffffffsfw",
		"wwwwwwwXwwwwwwww",
	],
	"small_house": [
		"wwwwwwwwwwwwwwwwww",
		"wfsffffffwbbffffhw",
		"wffffffffwfffffffw",
		"wffFfffffwwwfffffw",
		"wfffffffffffsfTffw",
		"wfsffffffffffffffw",
		"wwwwwwwwXwwwwwwwww",
	],
	"penthouse": [
		"wwwwwwwwwwwwwwwwwwwwww",
		"wfsfffffffffwbbfffffhw",
		"wffffTfffffffffffffffw",
		"wffffffwwwwfffffffFffw",
		"wffffffffffffffffffffw",
		"wfsfffffffffffffffssfw",
		"wwwwwwwwwXwwwwwwwwwwww",
	],
}

const SHOP_STOCK := [
	"instant_noodles", "canned_dinner", "deli_sandwich", "energy_drink",
	"six_pack", "candy_bar", "gas_station_burrito",
]

const DECOR_TEXTURES := {
	"table": "res://assets/props/table.png",
	"chair": "res://assets/props/chair.png",
	"plant": "res://assets/props/plant.png",
}

const DECOR_OFFSETS := {
	"table": Vector2(0, -5),
	"chair": Vector2(0, -3),
	"plant": Vector2(0, -8),
}

const DECOR_BY_LOCATION := {
	"loc_diner": [
		{"kind": "table", "cell": Vector2i(4, 1)},
		{"kind": "chair", "cell": Vector2i(3, 1)},
		{"kind": "chair", "cell": Vector2i(5, 1)},
		{"kind": "table", "cell": Vector2i(9, 1)},
		{"kind": "chair", "cell": Vector2i(8, 1)},
		{"kind": "chair", "cell": Vector2i(10, 1)},
		{"kind": "table", "cell": Vector2i(9, 5)},
		{"kind": "chair", "cell": Vector2i(8, 5)},
		{"kind": "chair", "cell": Vector2i(10, 5)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "plant", "cell": Vector2i(12, 6)},
	],
	"loc_store": [
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "table", "cell": Vector2i(4, 3)},
		{"kind": "chair", "cell": Vector2i(8, 3)},
		{"kind": "plant", "cell": Vector2i(10, 4)},
		{"kind": "chair", "cell": Vector2i(9, 1)},
	],
	"loc_bricks": [
		{"kind": "table", "cell": Vector2i(4, 2)},
		{"kind": "chair", "cell": Vector2i(3, 2)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "plant", "cell": Vector2i(12, 5)},
	],
	"loc_offices": [
		{"kind": "table", "cell": Vector2i(3, 1)},
		{"kind": "chair", "cell": Vector2i(4, 1)},
		{"kind": "table", "cell": Vector2i(10, 4)},
		{"kind": "chair", "cell": Vector2i(11, 4)},
		{"kind": "plant", "cell": Vector2i(1, 5)},
		{"kind": "plant", "cell": Vector2i(14, 1)},
	],
	"loc_site": [
		{"kind": "table", "cell": Vector2i(8, 3)},
		{"kind": "chair", "cell": Vector2i(9, 3)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
	],
	"loc_bar": [
		{"kind": "table", "cell": Vector2i(3, 1)},
		{"kind": "chair", "cell": Vector2i(4, 1)},
		{"kind": "table", "cell": Vector2i(8, 4)},
		{"kind": "chair", "cell": Vector2i(7, 4)},
		{"kind": "plant", "cell": Vector2i(1, 4)},
	],
	"loc_jail": [
		{"kind": "table", "cell": Vector2i(10, 3)},
		{"kind": "chair", "cell": Vector2i(11, 3)},
		{"kind": "chair", "cell": Vector2i(13, 3)},
	],
}

const HOME_DECOR_BY_HOUSING := {
	"shelter_cot": [
		{"kind": "chair", "cell": Vector2i(4, 1)},
		{"kind": "chair", "cell": Vector2i(7, 1)},
		{"kind": "table", "cell": Vector2i(9, 4)},
	],
	"weekly_motel": [
		{"kind": "table", "cell": Vector2i(4, 3)},
		{"kind": "chair", "cell": Vector2i(5, 3)},
	],
	"bricks_unit": [
		{"kind": "table", "cell": Vector2i(4, 2)},
		{"kind": "chair", "cell": Vector2i(3, 2)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "plant", "cell": Vector2i(12, 5)},
	],
	"decent_apartment": [
		{"kind": "table", "cell": Vector2i(4, 4)},
		{"kind": "chair", "cell": Vector2i(5, 4)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "plant", "cell": Vector2i(14, 5)},
	],
	"small_house": [
		{"kind": "table", "cell": Vector2i(5, 5)},
		{"kind": "chair", "cell": Vector2i(6, 5)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "plant", "cell": Vector2i(16, 1)},
		{"kind": "plant", "cell": Vector2i(15, 5)},
	],
	"penthouse": [
		{"kind": "table", "cell": Vector2i(5, 2)},
		{"kind": "chair", "cell": Vector2i(6, 2)},
		{"kind": "table", "cell": Vector2i(14, 5)},
		{"kind": "chair", "cell": Vector2i(15, 5)},
		{"kind": "plant", "cell": Vector2i(1, 1)},
		{"kind": "plant", "cell": Vector2i(18, 1)},
		{"kind": "plant", "cell": Vector2i(18, 5)},
	],
}


func _ready() -> void:
	layout_id = _layout_id()
	var map: Array = HOME_MAPS.get(layout_id, MAPS.get(location_id, MAPS["loc_diner"]))
	var fridge_scene: PackedScene = load("res://scenes/props/Fridge.tscn")
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			match row[x]:
				"w", "C":
					set_wall(cell)
				"f":
					set_ground(cell, FLOOR)
				"s":
					set_ground(cell, FLOOR)
					npc_spawn_points.append(cell_to_world(cell))
				"F":
					set_ground(cell, FLOOR)
					var fridge := fridge_scene.instantiate()
					fridge.position = cell_to_world(cell)
					add_child(fridge)
				"W":
					set_ground(cell, FLOOR)
					var spot := WorkSpot.new()
					spot.workplace_id = location_id
					spot.position = cell_to_world(cell)
					add_child(spot)
				"R":
					set_ground(cell, FLOOR)
					var desk := RecordsDesk.new()
					desk.position = cell_to_world(cell)
					add_child(desk)
				"S":
					set_ground(cell, FLOOR)
					var counter := ShopCounter.new()
					counter.stock = SHOP_STOCK
					counter.position = cell_to_world(cell)
					add_child(counter)
				"B":
					set_ground(cell, FLOOR)
					var bar := BarCounter.new()
					bar.position = cell_to_world(cell)
					add_child(bar)
				"b":
					set_ground(cell, FLOOR)
					var bed := Amenity.new()
					var sheet: CharacterSheet = WorldState.player_sheet
					var bed_q := 1.0
					if sheet != null:
						var home := ContentDB.get_housing(sheet.housing_id)
						bed_q = (home.quality if home else 1.0) * Housing.furniture_quality(sheet, "bed")
					var bed_name := "the jail bunk" if location_id == "loc_jail" else "your bed"
					var bed_verb := "Sit on" if location_id == "loc_jail" else "Sleep in"
					bed.configure("bed", bed_q, bed_name, bed_verb, Color(0.5, 0.55, 0.75))
					bed.position = cell_to_world(cell)
					add_child(bed)
				"h":
					set_ground(cell, FLOOR)
					var shower := Amenity.new()
					shower.configure("shower", 1.0, "the shower", "Use", Color(0.6, 0.75, 0.85))
					shower.position = cell_to_world(cell)
					add_child(shower)
				"T":
					set_ground(cell, FLOOR)
					var tv := Amenity.new()
					var tv_q := 1.0
					if WorldState.player_sheet != null and location_id == "loc_bricks":
						tv_q = Housing.furniture_quality(WorldState.player_sheet, "tv")
					tv.configure("tv", tv_q, "the TV", "Watch", Color(0.2, 0.2, 0.25))
					tv.position = cell_to_world(cell)
					add_child(tv)
				"D":
					set_ground(cell, FLOOR)
					var dealer := DealerSpot.new()
					dealer.position = cell_to_world(cell)
					add_child(dealer)
				"G":
					set_ground(cell, FLOOR)
					var fence := FenceSpot.new()
					fence.position = cell_to_world(cell)
					add_child(fence)
				"X":
					place_door(cell, "exterior", "Leave")
					entry_point = cell_to_world(cell + Vector2i(0, -1))
	_place_decor()
	if npc_spawn_points.is_empty():
		npc_spawn_points.append(entry_point)


func _layout_id() -> String:
	if location_id == "loc_bricks" and WorldState.player_sheet != null:
		var housing_id := str(WorldState.player_sheet.housing_id)
		if HOME_MAPS.has(housing_id):
			return housing_id
	return location_id


func get_npc_spawn_position(_npc) -> Vector2:
	if npc_spawn_points.is_empty():
		return entry_point
	var key := location_id
	if _npc != null:
		key += ":%s" % str(_npc.get("id"))
	return npc_spawn_points[absi(hash(key)) % npc_spawn_points.size()]


func _place_decor() -> void:
	var decor: Array = HOME_DECOR_BY_HOUSING.get(layout_id, DECOR_BY_LOCATION.get(location_id, []))
	var index := 0
	for item in decor:
		var kind := str(item.get("kind", ""))
		if not DECOR_TEXTURES.has(kind):
			continue
		var texture: Texture2D = load(DECOR_TEXTURES[kind])
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "DecorSprite_%02d" % index
		sprite.texture = texture
		sprite.texture_filter = 1
		var cell: Vector2i = item.get("cell", Vector2i.ZERO)
		sprite.position = cell_to_world(cell) + DECOR_OFFSETS.get(kind, Vector2.ZERO)
		add_child(sprite)
		index += 1
