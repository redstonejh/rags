extends Node
## The NPC simulation engine.
##
## Tier 0 (abstract): every NPC ticks every SIM_TICK_MINUTES game-minutes —
## schedule evaluation, abstract travel by timer, coarse needs. No nodes.
##
## Tier 1 (embodied): NPCs sharing the player's location get an NPCAgent
## puppet. The record stays the single source of truth; the puppet is
## cosmetic until M4/M5 brains take over for interactions.

const SIM_TICK_MINUTES := 10
const EXTERIOR_EMBODY_RADIUS := 620.0
const EXTERIOR_DESPAWN_RADIUS := 820.0
const MAX_EMBODIED := 30

## Set by the active world scene (Main wires this): must provide
## get_npc_spawn_position(record, arriving: bool) -> Vector2 and be the
## parent for agents. Null = no embodiment (menus, headless tests).
var spawn_host: Node2D = null
var player_node: Node2D = null

var _agent_scene: PackedScene = preload("res://scenes/npc/NPCAgent.tscn")
var _rng := RandomNumberGenerator.new()
var _embody_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	EventBus.minute_passed.connect(_on_minute_passed)
	EventBus.player_location_changed.connect(func(_loc: String) -> void: _despawn_all())


func _process(delta: float) -> void:
	_embody_timer += delta
	if _embody_timer >= 0.5:
		_embody_timer = 0.0
		_update_embodiment()


# ------------------------------------------------------------ abstract sim

func _on_minute_passed(total_minutes: int) -> void:
	if total_minutes % SIM_TICK_MINUTES != 0:
		return
	var minute_of_day := total_minutes % GameClock.MINUTES_PER_DAY
	for npc in WorldState.npcs.values():
		_tick_npc(npc, total_minutes, minute_of_day)


func _tick_npc(npc: NPCRecord, now: int, minute_of_day: int) -> void:
	if not npc.alive:
		npc.current_activity = "dead"
		return
	# Arrivals.
	if npc.traveling and now >= npc.travel_arrive_min:
		npc.traveling = false
		npc.current_location_id = npc.travel_to_id
		npc.travel_to_id = ""

	# Schedule evaluation.
	var block := npc.scheduled_block(minute_of_day)
	var want := npc.resolve_location(str(block.get("loc", "home")))
	npc.current_activity = str(block.get("activity", "idle"))

	if not npc.traveling and npc.current_location_id != want:
		_start_travel(npc, want, now)

	# Coarse needs: activity-shaped drift per sim tick.
	var dt := float(SIM_TICK_MINUTES)
	match npc.current_activity:
		"sleeping":
			npc.energy = minf(npc.energy + 0.3 * dt, 100.0)
		"eating":
			npc.hunger = minf(npc.hunger + 2.0 * dt, 100.0)
		_:
			npc.energy = maxf(npc.energy - 0.06 * dt, 0.0)
	npc.hunger = maxf(npc.hunger - 0.07 * dt, 0.0)
	if npc.hunger < 25.0 and npc.current_location_id == npc.home_id:
		npc.hunger = 90.0 # raided their own fridge, abstractly


func _start_travel(npc: NPCRecord, dest_id: String, now: int) -> void:
	var from_pos := npc.abstract_position(now)
	var to_pos: Vector2
	if dest_id == "exterior":
		# Wandering/patrolling: pick a street anchor to stand around.
		var host := spawn_host
		if host != null and host.has_method("random_exterior_point"):
			to_pos = host.random_exterior_point(_rng)
		else:
			to_pos = Locations.door_pos("exterior") + Vector2(_rng.randf_range(-300, 300), _rng.randf_range(-200, 200))
		npc.flags["anchor"] = [to_pos.x, to_pos.y]
	else:
		to_pos = Locations.door_pos(dest_id)
	var minutes := maxi(1, ceili(from_pos.distance_to(to_pos) / TileWorld.TILE / Locations.WALK_TILES_PER_MINUTE))
	npc.traveling = true
	npc.travel_to_id = dest_id
	npc.travel_from_pos = from_pos
	npc.travel_to_pos = to_pos
	npc.travel_depart_min = now
	npc.travel_arrive_min = now + minutes
	# While walking the streets, the NPC is observably "exterior".
	npc.current_location_id = "exterior"


# ------------------------------------------------------------ embodiment

func compute_desired_embodied() -> Array:
	var player_loc: String = WorldState.player_location_id
	var now := GameClock.total_minutes
	var picks: Array = []
	if player_loc == "exterior":
		if player_node == null:
			return []
		var ppos := player_node.global_position
		for npc in WorldState.npcs.values():
			if not npc.alive or npc.current_location_id != "exterior":
				continue
			var radius := EXTERIOR_DESPAWN_RADIUS if npc.agent != null else EXTERIOR_EMBODY_RADIUS
			if npc.abstract_position(now).distance_to(ppos) <= radius:
				picks.append(npc)
		picks.sort_custom(func(a: NPCRecord, b: NPCRecord) -> bool:
			return a.abstract_position(now).distance_to(ppos) < b.abstract_position(now).distance_to(ppos))
	else:
		for npc in WorldState.npcs.values():
			if npc.alive and npc.current_location_id == player_loc:
				picks.append(npc)
	if picks.size() > MAX_EMBODIED:
		picks.resize(MAX_EMBODIED)
	return picks


func _update_embodiment() -> void:
	if spawn_host == null or not is_instance_valid(spawn_host):
		return
	var desired := compute_desired_embodied()
	var desired_ids := {}
	for npc in desired:
		desired_ids[npc.id] = true
	# Despawn the no-longer-wanted.
	for npc in WorldState.npcs.values():
		if npc.agent != null and not desired_ids.has(npc.id):
			_despawn(npc)
	# Spawn the newly wanted.
	for npc in desired:
		if npc.agent == null:
			_spawn(npc)


func _spawn(npc: NPCRecord) -> void:
	var agent := _agent_scene.instantiate()
	agent.setup(npc)
	npc.agent = agent
	spawn_host.add_child(agent)
	if WorldState.player_location_id == "exterior":
		agent.global_position = npc.abstract_position(GameClock.total_minutes)
	elif spawn_host.has_method("get_npc_spawn_position"):
		agent.global_position = spawn_host.get_npc_spawn_position(npc)


func _despawn(npc: NPCRecord) -> void:
	if npc.agent != null:
		if is_instance_valid(npc.agent):
			npc.agent.queue_free()
		npc.agent = null


func _despawn_all() -> void:
	for npc in WorldState.npcs.values():
		_despawn(npc)
