class_name NPCRecord
extends RefCounted
## The NPC. Always exists in WorldState; the visible NPCAgent is a disposable
## puppet. This record is the single source of truth for everything about
## this person — needs, schedule, money, personality, and (from M4) memories
## and relationships.

var id: String = ""
var display_name: String = ""
var archetype_id: String = ""
var appearance_tags: Array = []
## TRUE stats — hidden from the player until the Reality Check perk tree.
var stats: Dictionary = {}
## bravery, greed, civic_duty, kindness, chattiness, jealousy: 0-100.
var personality: Dictionary = {}
## ~10-15% of NPCs: appearance deliberately contradicts stats.
var is_subversion: bool = false

var home_id: String = ""
var workplace_id: String = ""
## Minutes of jitter applied to schedule block starts (-40..40).
var schedule_offset: int = 0

var current_location_id: String = "exterior"
var current_activity: String = "idle"
## Travel state (abstract): set while walking between locations.
var traveling: bool = false
var travel_to_id: String = ""
var travel_from_pos: Vector2 = Vector2.ZERO
var travel_to_pos: Vector2 = Vector2.ZERO
var travel_depart_min: int = 0
var travel_arrive_min: int = 0

var money_cents: int = 0
var energy: float = 100.0
var hunger: float = 100.0

var relationships: Dictionary = {}  # other id ("player" or npc id) -> -100..100
var memories: Array = []            # M4: Memory dicts
var flags: Dictionary = {}
## Dead NPCs stay in WorldState forever — the town remembers — but stop
## ticking, working, and gossiping. Their job opens up.
var alive: bool = true
var age_years: float = 35.0

## Not serialized — the live puppet, if embodied.
var agent: Node = null


const MEMORY_CAP := 24

func archetype() -> ArchetypeDef:
	return ContentDB.archetypes.get(archetype_id)


func is_cop() -> bool:
	var arch := archetype()
	return arch != null and "cop" in arch.tags


func rel(other_id: String) -> float:
	return float(relationships.get(other_id, 0.0))


func change_rel(other_id: String, delta: float) -> void:
	var value := clampf(rel(other_id) + delta, -100.0, 100.0)
	relationships[other_id] = value
	if other_id == "player":
		EventBus.relationship_changed.emit(id, value)


## Memories are plain dicts (JSON-friendly): kind, subject ("player" or an
## npc id), text, tone (-1..1), salience (gossip-worthiness, decays daily),
## day, secondhand. Capped at MEMORY_CAP, lowest salience evicted first.
func add_memory(kind: String, subject: String, text: String, tone: float, salience: float,
		secondhand := false) -> void:
	memories.append({
		"kind": kind, "subject": subject, "text": text,
		"tone": tone, "salience": salience,
		"day": GameClock.day, "secondhand": secondhand,
	})
	if memories.size() > MEMORY_CAP:
		memories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("salience", 0)) > float(b.get("salience", 0)))
		memories.resize(MEMORY_CAP)


func knows_memory(subject: String, text: String) -> bool:
	for m in memories:
		if m.get("subject", "") == subject and m.get("text", "") == text:
			return true
	return false


## The juiciest thing this person knows — what they'd share at the bar.
func top_gossip(min_salience: float = 4.0) -> Dictionary:
	var best: Dictionary = {}
	var best_salience := min_salience
	for m in memories:
		if float(m.get("salience", 0.0)) >= best_salience:
			best_salience = float(m.salience)
			best = m
	return best


## Where this NPC's schedule says they should be at `minute_of_day`.
func scheduled_block(minute_of_day: int) -> Dictionary:
	var arch := archetype()
	if arch == null or arch.schedule.is_empty():
		return {"loc": home_id, "activity": "idle"}
	var adjusted := posmod(minute_of_day - schedule_offset, 1440)
	var best: Dictionary = arch.schedule.back() # wraps from yesterday
	for block in arch.schedule:
		if int(block.h) * 60 <= adjusted:
			best = block
	return best


func resolve_location(token: String) -> String:
	match token:
		"home": return home_id
		"work": return workplace_id if workplace_id != "" else home_id
		_: return token


## Abstract world position right now (for exterior embodiment + debug map).
func abstract_position(now_min: int) -> Vector2:
	if traveling:
		var span := float(travel_arrive_min - travel_depart_min)
		var t: float = clampf((now_min - travel_depart_min) / maxf(span, 1.0), 0.0, 1.0)
		return travel_from_pos.lerp(travel_to_pos, t)
	return Locations.door_pos(current_location_id)


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "archetype_id": archetype_id,
		"appearance_tags": appearance_tags.duplicate(),
		"stats": stats.duplicate(), "personality": personality.duplicate(),
		"is_subversion": is_subversion,
		"home_id": home_id, "workplace_id": workplace_id,
		"schedule_offset": schedule_offset,
		"current_location_id": current_location_id,
		"current_activity": current_activity,
		"traveling": traveling, "travel_to_id": travel_to_id,
		"travel_from_pos": [travel_from_pos.x, travel_from_pos.y],
		"travel_to_pos": [travel_to_pos.x, travel_to_pos.y],
		"travel_depart_min": travel_depart_min, "travel_arrive_min": travel_arrive_min,
		"money_cents": money_cents, "energy": energy, "hunger": hunger,
		"relationships": relationships.duplicate(),
		"memories": memories.duplicate(true),
		"flags": flags.duplicate(true),
		"alive": alive,
		"age_years": age_years,
	}


static func from_dict(d: Dictionary) -> NPCRecord:
	var n := NPCRecord.new()
	n.id = d.get("id", "")
	n.display_name = d.get("display_name", "Somebody")
	n.archetype_id = d.get("archetype_id", "")
	n.appearance_tags = d.get("appearance_tags", []).duplicate()
	# JSON round-trips all numbers as floats — restore int stats.
	for k in d.get("stats", {}):
		n.stats[k] = int(d.stats[k])
	for k in d.get("personality", {}):
		n.personality[k] = int(d.personality[k])
	n.is_subversion = d.get("is_subversion", false)
	n.home_id = d.get("home_id", "loc_bricks")
	n.workplace_id = d.get("workplace_id", "")
	n.schedule_offset = int(d.get("schedule_offset", 0))
	n.current_location_id = d.get("current_location_id", "exterior")
	n.current_activity = d.get("current_activity", "idle")
	n.traveling = d.get("traveling", false)
	n.travel_to_id = d.get("travel_to_id", "")
	var fp: Array = d.get("travel_from_pos", [0, 0])
	var tp: Array = d.get("travel_to_pos", [0, 0])
	n.travel_from_pos = Vector2(fp[0], fp[1])
	n.travel_to_pos = Vector2(tp[0], tp[1])
	n.travel_depart_min = int(d.get("travel_depart_min", 0))
	n.travel_arrive_min = int(d.get("travel_arrive_min", 0))
	n.money_cents = int(d.get("money_cents", 0))
	n.energy = float(d.get("energy", 100.0))
	n.hunger = float(d.get("hunger", 100.0))
	n.relationships = d.get("relationships", {}).duplicate()
	n.memories = d.get("memories", []).duplicate(true)
	n.flags = d.get("flags", {}).duplicate(true)
	n.alive = d.get("alive", true)
	n.age_years = float(d.get("age_years", 35.0))
	return n
