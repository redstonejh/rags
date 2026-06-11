extends Node
## ALL mutable simulation state lives here (and only here). This is what
## gets saved: the player sheet, every NPC record, and world flags.

var player_sheet: CharacterSheet = null
var player_location_id: String = "exterior"
var world_seed: int = 0
var npcs: Dictionary = {} # id -> NPCRecord


func new_game(sheet: CharacterSheet) -> void:
	player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	player_location_id = "exterior"
	world_seed = randi()
	npcs = WorldGen.generate(world_seed)


## Lets Main.tscn run standalone from the editor (F5 on the scene) without
## going through the menu — creates a debug drifter in a generated town.
func ensure_player_sheet() -> void:
	if player_sheet != null:
		return
	var sheet := CharacterSheet.new()
	sheet.char_name = "Debug Drifter"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 40000
	new_game(sheet)


func to_dict() -> Dictionary:
	var npc_dicts: Dictionary = {}
	for id in npcs:
		npc_dicts[id] = npcs[id].to_dict()
	return {
		"player": player_sheet.to_dict() if player_sheet else {},
		"player_location_id": player_location_id,
		"world_seed": world_seed,
		"npcs": npc_dicts,
	}


func load_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("player", {})
	player_sheet = CharacterSheet.from_dict(p) if not p.is_empty() else null
	if player_sheet:
		player_sheet.rebuild_needs_multipliers()
	player_location_id = d.get("player_location_id", "exterior")
	world_seed = int(d.get("world_seed", 0))
	npcs.clear()
	var npc_dicts: Dictionary = d.get("npcs", {})
	for id in npc_dicts:
		npcs[id] = NPCRecord.from_dict(npc_dicts[id])
