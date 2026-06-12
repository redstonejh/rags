class_name GossipSystem
extends Node
## Gossip propagation + NPC↔NPC relationship drift. Plain Node in Main.tscn.
##
## Hourly: co-located, awake NPCs swap their juiciest memories. A memory
## about the player shifts the listener's opinion of the player — that's how
## a stranger knows what you did two days ago. Daily: memories fade (a
## little) and the boring ones evaporate.

const SECONDHAND_FACTOR := 0.6     # gossip arrives slightly degraded
const DAILY_DECAY := 0.88
const FORGET_BELOW := 1.5
const FAMILIARITY_DRIFT := 0.5     # talking to someone warms you to them
const REL_PER_TONE := 3.0          # how much a juicy story moves opinions


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.day_passed.connect(_on_day_passed)


func _on_hour_passed(_hour: int) -> void:
	var groups: Dictionary = {}
	for npc in WorldState.npcs.values():
		if npc.current_activity == "sleeping" or npc.traveling:
			continue
		var loc: String = npc.current_location_id
		if not groups.has(loc):
			groups[loc] = []
		groups[loc].append(npc)
	for loc in groups:
		var room: Array = groups[loc]
		if room.size() < 2:
			continue
		var exchanges: int = mini(ceili(room.size() / 3.0), 4)
		for _i in exchanges:
			_exchange(room)


func _exchange(room: Array) -> void:
	var speaker: NPCRecord = _weighted_by_chattiness(room)
	var listener: NPCRecord = room.pick_random()
	if listener == speaker:
		return
	# Familiarity: just talking warms people up — and the jealous sour fast.
	var drift := FAMILIARITY_DRIFT
	if int(speaker.personality.get("jealousy", 50)) > 75 and randf() < 0.15:
		drift = -2.0
	speaker.change_rel(listener.id, drift)
	listener.change_rel(speaker.id, drift)
	share(speaker, listener)


## One unit of gossip: speaker's juiciest memory -> listener, degraded.
## Hearing a story about someone moves your opinion of them. Static so
## tests can drive it deterministically.
static func share(speaker: NPCRecord, listener: NPCRecord) -> bool:
	var story: Dictionary = speaker.top_gossip()
	if story.is_empty():
		return false
	var subject := str(story.get("subject", ""))
	var text := str(story.get("text", ""))
	if listener.knows_memory(subject, text):
		return false
	listener.add_memory(str(story.get("kind", "gossip")), subject, text,
			float(story.get("tone", 0.0)),
			float(story.get("salience", 0.0)) * SECONDHAND_FACTOR, true)
	if subject != listener.id: # hearing about yourself works differently
		listener.change_rel(subject, float(story.get("tone", 0.0)) * REL_PER_TONE)
	return true


func _weighted_by_chattiness(room: Array) -> NPCRecord:
	var total := 0.0
	for npc in room:
		total += float(npc.personality.get("chattiness", 50))
	var roll := randf() * total
	for npc in room:
		roll -= float(npc.personality.get("chattiness", 50))
		if roll <= 0.0:
			return npc
	return room.back()


func _on_day_passed(_day: int) -> void:
	for npc in WorldState.npcs.values():
		decay_memories(npc)


static func decay_memories(npc: NPCRecord) -> void:
	var kept: Array = []
	for m in npc.memories:
		m["salience"] = float(m.get("salience", 0.0)) * DAILY_DECAY
		if m.salience >= FORGET_BELOW:
			kept.append(m)
	npc.memories = kept
