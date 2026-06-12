extends Node
## ALL mutable simulation state lives here (and only here). This is what
## gets saved: the player sheet, every NPC record, and world flags.
##
## Lifecycle: new_world() builds a fresh town for a first life; start_life()
## drops a NEW character into the EXISTING town — the persistent-world
## permadeath feature. The town doesn't reset because you did.

var player_sheet: CharacterSheet = null
var player_location_id: String = "exterior"
var world_seed: int = 0
var npcs: Dictionary = {} # id -> NPCRecord
## True once a town has been generated; survives the player's death.
var world_exists: bool = false
var crime_cases: Dictionary = {} # id -> CrimeCase
var _case_serial: int = 0


func next_case_serial() -> int:
	_case_serial += 1
	return _case_serial


func _ready() -> void:
	# Death is written to the world immediately — ironman means ironman.
	EventBus.player_died.connect(_on_player_died)


func _on_player_died(_cause: String) -> void:
	if player_sheet != null and player_sheet.alive:
		player_sheet.alive = false
		SaveManager.save_game()


## A brand-new town for a brand-new (first) life.
func new_world(sheet: CharacterSheet) -> void:
	player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	player_location_id = "exterior"
	world_seed = randi()
	npcs = WorldGen.generate(world_seed)
	crime_cases = {}
	_case_serial = 0
	world_exists = true
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 7 * 60 # day 1, 7 AM


## A new character in the SAME town: NPCs, clock, and history persist.
func start_life(sheet: CharacterSheet) -> void:
	var prev_lives := player_sheet.lives_lived if player_sheet != null else 0
	sheet.lives_lived = prev_lives + 1
	player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	player_location_id = "exterior"


## Back-compat alias (M1/M2 tests and tools call this).
func new_game(sheet: CharacterSheet) -> void:
	new_world(sheet)


## Lets Main.tscn run standalone from the editor (F5 on the scene) without
## going through the menu — creates a debug drifter in a generated town.
func ensure_player_sheet() -> void:
	if player_sheet != null:
		return
	var sheet := CharacterSheet.new()
	sheet.char_name = "Debug Drifter"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 40000
	new_world(sheet)


func to_dict() -> Dictionary:
	var npc_dicts: Dictionary = {}
	for id in npcs:
		npc_dicts[id] = npcs[id].to_dict()
	var case_dicts: Dictionary = {}
	for id in crime_cases:
		case_dicts[id] = crime_cases[id].to_dict()
	return {
		"player": player_sheet.to_dict() if player_sheet else {},
		"player_location_id": player_location_id,
		"world_seed": world_seed,
		"world_exists": world_exists,
		"npcs": npc_dicts,
		"crime_cases": case_dicts,
		"case_serial": _case_serial,
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
	world_exists = d.get("world_exists", not npcs.is_empty())
	crime_cases.clear()
	var case_dicts: Dictionary = d.get("crime_cases", {})
	for id in case_dicts:
		crime_cases[id] = CrimeCase.from_dict(case_dicts[id])
	_case_serial = int(d.get("case_serial", crime_cases.size()))
