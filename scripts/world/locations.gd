class_name Locations
extends RefCounted
## Static location registry. Definitions live here; door world-positions are
## filled in by the town when it builds its map (markers -> cells).
##
## kind: "interior" = enterable scene, "abstract" = NPCs go there but the
## player can't (yet) — the door just swallows them believably.

const WALK_TILES_PER_MINUTE := 4.5
const TILE := 32

static var defs := {
	"exterior": {"display_name": "the street", "kind": "exterior"},
	"loc_diner": {"display_name": "Mel's Diner", "kind": "interior"},
	"loc_store": {"display_name": "QuikStop Corner Store", "kind": "interior"},
	"loc_bricks": {"display_name": "The Bricks (lobby)", "kind": "interior"},
	"loc_offices": {"display_name": "Vantage Plaza offices", "kind": "abstract"},
	"loc_rowhouse_a": {"display_name": "Rowhouses (east)", "kind": "abstract"},
	"loc_rowhouse_b": {"display_name": "Rowhouses (west)", "kind": "abstract"},
	"loc_bar": {"display_name": "The Rusty Anchor", "kind": "abstract"},
	"loc_site": {"display_name": "the construction site", "kind": "abstract"},
}

## Filled by town.gd at build time: id -> Vector2 (world position of the door).
static var door_positions := {}


static func register_door(id: String, world_pos: Vector2) -> void:
	door_positions[id] = world_pos


static func door_pos(id: String) -> Vector2:
	return door_positions.get(id, Vector2.ZERO)


static func display_name(id: String) -> String:
	return defs.get(id, {}).get("display_name", id)


static func is_interior(id: String) -> bool:
	return defs.get(id, {}).get("kind", "") == "interior"


static func travel_minutes(from_id: String, to_id: String) -> int:
	var a := door_pos(from_id)
	var b := door_pos(to_id)
	var tiles := a.distance_to(b) / TILE
	return maxi(1, ceili(tiles / WALK_TILES_PER_MINUTE))
