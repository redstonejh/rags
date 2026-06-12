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
}

const SHOP_STOCK := [
	"instant_noodles", "canned_dinner", "deli_sandwich", "energy_drink",
	"six_pack", "candy_bar", "gas_station_burrito",
]


func _ready() -> void:
	var map: Array = MAPS.get(location_id, MAPS["loc_diner"])
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
					bed.configure("bed", bed_q, "your bed", "Sleep in", Color(0.5, 0.55, 0.75))
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
	if npc_spawn_points.is_empty():
		npc_spawn_points.append(entry_point)


func get_npc_spawn_position(_npc) -> Vector2:
	return npc_spawn_points.pick_random()
