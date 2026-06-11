class_name WorldGen
extends RefCounted
## Generates the town's population at new-game time. Every NPC is built by
## the Coherence Engine so their stats match their look — except the
## deliberate subversions (~12%), whose appearance lies. That gap is the
## fuel for the Reality Check system.

const HOME_POOL := ["loc_bricks", "loc_rowhouse_a", "loc_rowhouse_b"]
const SUBVERSION_RATE := 0.12
const VICES := ["booze", "cards", "gossip", "spite", "shopping", "none", "none"]


static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var npcs: Dictionary = {}
	var serial := 0

	for arch in ContentDB.archetypes.values():
		for _i in arch.count:
			serial += 1
			var n := NPCRecord.new()
			n.id = "npc_%04d" % serial
			n.display_name = Coherence.random_name(rng)
			n.archetype_id = arch.id
			n.appearance_tags = Coherence.random_appearance(rng, arch.stat_bias)
			n.is_subversion = rng.randf() < SUBVERSION_RATE
			if n.is_subversion:
				# Looks one way, IS another: stats roll against a shuffled bias.
				var fake_bias := {}
				var stat_pool := CharacterSheet.STAT_IDS.duplicate()
				stat_pool.shuffle()
				for k in arch.stat_bias:
					fake_bias[stat_pool.pop_back()] = arch.stat_bias[k]
				n.stats = Coherence.allocate_stats(rng, fake_bias, [])
			else:
				n.stats = Coherence.allocate_stats(rng, arch.stat_bias, n.appearance_tags)

			n.personality = {
				"bravery": _roll_stat(rng), "greed": _roll_stat(rng),
				"civic_duty": 100 if "cop" in arch.tags else _roll_stat(rng),
				"kindness": _roll_stat(rng), "chattiness": _roll_stat(rng),
				"jealousy": _roll_stat(rng),
			}
			n.flags["vice"] = VICES[rng.randi() % VICES.size()]
			if "cop" in arch.tags:
				n.flags["corruption"] = clampi(int(rng.randfn(25.0, 18.0)), 0, 95)

			n.home_id = HOME_POOL[rng.randi() % HOME_POOL.size()]
			n.workplace_id = arch.workplace_id
			n.schedule_offset = rng.randi_range(-40, 40)
			n.money_cents = rng.randi_range(2000, 40000)
			n.current_location_id = n.home_id
			n.current_activity = "sleeping"
			n.energy = rng.randf_range(60.0, 100.0)
			n.hunger = rng.randf_range(50.0, 100.0)
			npcs[n.id] = n

	return npcs


static func _roll_stat(rng: RandomNumberGenerator) -> int:
	return clampi(int(rng.randfn(50.0, 18.0)), 5, 95)
