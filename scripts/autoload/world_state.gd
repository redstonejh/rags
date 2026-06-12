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
var sim_rng_seed: int = 0
var sim_rng_state: int = 0
var town_rng_seed: int = 0
var town_rng_state: int = 0
var crime_rng_seed: int = 0
var crime_rng_state: int = 0
var gossip_rng_seed: int = 0
var gossip_rng_state: int = 0
var npcs: Dictionary = {} # id -> NPCRecord
## True once a town has been generated; survives the player's death.
var world_exists: bool = false
var crime_cases: Dictionary = {} # id -> CrimeCase
var _case_serial: int = 0
## Every finished life leaves one paragraph behind. The next character
## reads about the last one — the archive IS the legacy record.
var obituaries: Array = []
## The Rust Harbor Gazette: the town narrating itself. [{day, text}], capped.
var gazette: Array = []
## Murder-hobo equilibrium: 0-100, crimes raise it, time lowers it.
var town_fear: float = 0.0

const GAZETTE_CAP := 60


func add_news(text: String) -> void:
	gazette.append({"day": GameClock.day, "text": text})
	while gazette.size() > GAZETTE_CAP:
		gazette.pop_front()


func next_case_serial() -> int:
	_case_serial += 1
	return _case_serial


func _ready() -> void:
	# Death is written to the world immediately — ironman means ironman.
	EventBus.player_died.connect(_on_player_died)


func _on_player_died(cause: String) -> void:
	if player_sheet != null and player_sheet.alive:
		player_sheet.alive = false
		obituaries.append(Body.obituary(player_sheet, cause))
		SaveManager.save_game()


## Retirement: your character stops being yours and becomes a full NPC.
## Nearly free in this architecture — the sheet becomes a record, the sim
## takes the wheel, and your next character can meet them.
func walk_away() -> NPCRecord:
	var sheet := player_sheet
	if sheet == null or not sheet.alive:
		return null
	var npc := NPCRecord.new()
	npc.id = "npc_walked_%02d" % sheet.lives_lived
	npc.display_name = sheet.char_name
	npc.archetype_id = "barfly" # retirement has a look
	npc.appearance_tags = sheet.appearance_tags.duplicate()
	for s in CharacterSheet.STAT_IDS:
		npc.stats[s] = sheet.get_stat(s)
	npc.personality = {"bravery": 50, "greed": 40, "civic_duty": 50,
			"kindness": 60, "chattiness": 60, "jealousy": 30}
	npc.age_years = sheet.age_years
	npc.home_id = "loc_bricks"
	npc.money_cents = sheet.cash_cents + sheet.bank_cents
	npc.relationships["player"] = 0.0
	npc.flags["was_player_life"] = sheet.lives_lived
	npcs[npc.id] = npc
	sheet.alive = false
	obituaries.append("%s walked away from the life you knew them in. They're still around. Ask at the bar." % sheet.char_name)
	SaveManager.save_game()
	return npc


## A brand-new town for a brand-new (first) life.
func new_world(sheet: CharacterSheet) -> void:
	player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	_start_origin_clocks(sheet)
	_set_origin_start_marker(sheet)
	player_location_id = "exterior"
	world_seed = randi()
	reset_sim_rng()
	reset_town_rng()
	reset_crime_rng()
	reset_gossip_rng()
	npcs = WorldGen.generate(world_seed)
	crime_cases = {}
	_case_serial = 0
	obituaries = []
	gazette = []
	town_fear = 0.0
	world_exists = true
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 7 * 60 # day 1, 7 AM


## A new character in the SAME town: NPCs, clock, and history persist.
func start_life(sheet: CharacterSheet) -> void:
	var prev_lives := player_sheet.lives_lived if player_sheet != null else 0
	sheet.lives_lived = prev_lives + 1
	player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	_start_origin_clocks(sheet)
	_set_origin_start_marker(sheet)
	player_location_id = "exterior"


## Origin timers that must start ticking at world time, not menu time.
func _start_origin_clocks(sheet: CharacterSheet) -> void:
	if sheet.has_tag("parole") and not sheet.flags.has("parole_start_day"):
		sheet.flags["parole_start_day"] = GameClock.day


func _set_origin_start_marker(sheet: CharacterSheet) -> void:
	if sheet == null or sheet.flags.has("start_location_id"):
		return
	var origin := ContentDB.get_origin(sheet.origin_id)
	var start_id := origin.starting_location_id if origin else ""
	if start_id != "":
		sheet.flags["start_location_id"] = start_id


## Back-compat alias (M1/M2 tests and tools call this).
func new_game(sheet: CharacterSheet) -> void:
	new_world(sheet)


func reset_sim_rng() -> void:
	sim_rng_seed = int(world_seed) + 1000003
	var rng := RandomNumberGenerator.new()
	rng.seed = sim_rng_seed
	sim_rng_state = rng.state


func reset_town_rng() -> void:
	town_rng_seed = int(world_seed) + 2000003
	var rng := RandomNumberGenerator.new()
	rng.seed = town_rng_seed
	town_rng_state = rng.state


func reset_crime_rng() -> void:
	crime_rng_seed = int(world_seed) + 3000003
	var rng := RandomNumberGenerator.new()
	rng.seed = crime_rng_seed
	crime_rng_state = rng.state


func reset_gossip_rng() -> void:
	gossip_rng_seed = int(world_seed) + 4000003
	var rng := RandomNumberGenerator.new()
	rng.seed = gossip_rng_seed
	gossip_rng_state = rng.state


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
		"sim_rng_seed": str(sim_rng_seed),
		"sim_rng_state": str(sim_rng_state),
		"town_rng_seed": str(town_rng_seed),
		"town_rng_state": str(town_rng_state),
		"crime_rng_seed": str(crime_rng_seed),
		"crime_rng_state": str(crime_rng_state),
		"gossip_rng_seed": str(gossip_rng_seed),
		"gossip_rng_state": str(gossip_rng_state),
		"world_exists": world_exists,
		"npcs": npc_dicts,
		"crime_cases": case_dicts,
		"case_serial": _case_serial,
		"obituaries": obituaries.duplicate(),
		"gazette": gazette.duplicate(true),
		"town_fear": town_fear,
	}


func load_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("player", {})
	player_sheet = CharacterSheet.from_dict(p) if not p.is_empty() else null
	if player_sheet:
		player_sheet.rebuild_needs_multipliers()
	player_location_id = d.get("player_location_id", "exterior")
	world_seed = int(d.get("world_seed", 0))
	sim_rng_seed = _saved_int(d.get("sim_rng_seed", int(world_seed) + 1000003),
			int(world_seed) + 1000003)
	sim_rng_state = _saved_int(d.get("sim_rng_state", 0), 0)
	if sim_rng_state == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = sim_rng_seed
		sim_rng_state = rng.state
	town_rng_seed = _saved_int(d.get("town_rng_seed", int(world_seed) + 2000003),
			int(world_seed) + 2000003)
	town_rng_state = _saved_int(d.get("town_rng_state", 0), 0)
	if town_rng_state == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = town_rng_seed
		town_rng_state = rng.state
	crime_rng_seed = _saved_int(d.get("crime_rng_seed", int(world_seed) + 3000003),
			int(world_seed) + 3000003)
	crime_rng_state = _saved_int(d.get("crime_rng_state", 0), 0)
	if crime_rng_state == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = crime_rng_seed
		crime_rng_state = rng.state
	gossip_rng_seed = _saved_int(d.get("gossip_rng_seed", int(world_seed) + 4000003),
			int(world_seed) + 4000003)
	gossip_rng_state = _saved_int(d.get("gossip_rng_state", 0), 0)
	if gossip_rng_state == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = gossip_rng_seed
		gossip_rng_state = rng.state
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
	obituaries = d.get("obituaries", []).duplicate()
	gazette = d.get("gazette", []).duplicate(true)
	town_fear = float(d.get("town_fear", 0.0))


func _saved_int(value, fallback: int) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			return int(value)
		_:
			return fallback
