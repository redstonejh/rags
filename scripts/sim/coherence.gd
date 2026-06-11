class_name Coherence
extends RefCounted
## The Coherence Engine: one stereotype table, three jobs —
## (1) "Deal Me a Life" random player generation (M1, here),
## (2) NPC generation (M2 reuses APPEARANCES + allocate_stats),
## (3) Reality Check perception guesses (M4 reads the same correlations).
##
## Random characters are never pure random: stats are allocated to make
## sense for who the person visibly is. The buff dockworker rolls STR-heavy;
## the bookish runaway rolls INT-heavy.

## appearance tag -> stat allocation bias. This IS the stereotype table the
## perception system will later use to (mis)judge NPCs.
const APPEARANCES := {
	"buff": {"STR": 3.0, "CON": 1.5},
	"wiry": {"DEX": 3.0},
	"heavyset": {"CON": 2.5, "STR": 1.0},
	"bookish": {"INT": 3.0},
	"glasses": {"INT": 2.0, "WIS": 1.0},
	"attractive": {"CHA": 3.0},
	"well_dressed": {"CHA": 2.0, "INT": 1.0},
	"weathered": {"WIS": 2.5, "CON": 1.0},
	"stern": {"WIS": 2.0},
	"friendly": {"CHA": 1.5},
	"awkward": {"INT": 1.5},
	"loud": {"CHA": 1.0, "STR": 0.5},
	"rugged": {"STR": 1.5, "CON": 1.5},
	"street": {"DEX": 1.5, "WIS": 1.0},
	"older": {"WIS": 2.0},
	"haggard": {},
	"plain": {},
	"intense": {},
}

const FIRST_NAMES := [
	"Doug", "Marlene", "Ray", "Tammy", "Earl", "Brenda", "Cliff", "Dot",
	"Gus", "Loretta", "Vern", "Patsy", "Mick", "Deb", "Sal", "Rhonda",
	"Wade", "Carla", "Bart", "Yolanda", "Chet", "Nadine", "Otis", "Faye",
]
const LAST_NAMES := [
	"Krebs", "Dutton", "Marsh", "Pulaski", "Gentry", "Hobbs", "Vance",
	"Crick", "Bauer", "Tibbs", "Mungo", "Sloane", "Pickett", "Drum",
	"Halloran", "Quigg", "Stubbs", "Vasquez", "Okafor", "Lindqvist",
]

const APPEARANCE_DESCRIPTORS := {
	"buff": "built like a vending machine",
	"wiry": "fast-looking in a way that worries people",
	"heavyset": "carrying some insulation against hard times",
	"bookish": "clearly owns a library card",
	"glasses": "squinting through repaired glasses",
	"attractive": "suspiciously good-looking for this town",
	"well_dressed": "dressed better than their bank balance",
	"weathered": "with a face like a closed factory",
	"stern": "who has never once laughed at a joke",
	"friendly": "with a smile that makes strangers overshare",
	"awkward": "who rehearses conversations in advance",
	"loud": "audible from two rooms away",
	"rugged": "with hands that have fixed things",
	"street": "who knows which alleys connect",
	"older": "old enough to know better",
	"haggard": "running on fumes and gas-station coffee",
	"plain": "the kind of face witnesses can't describe",
	"intense": "with eyes that make small talk difficult",
}

const BIO_HOOKS := [
	"owes everyone money",
	"former forklift champion, regional",
	"banned from two casinos and one church",
	"writes poetry nobody will ever see",
	"can name every regular at the diner",
	"left a whole life somewhere else",
	"undefeated at bar trivia, unemployed otherwise",
	"believes this year will be different",
	"has a plan, just needs forty dollars",
	"never talks about the thing with the boat",
]


static func random_appearance(rng: RandomNumberGenerator, bias: Dictionary, count: int = 3) -> Array:
	# Weight appearance tags by how well they align with the given stat bias,
	# so the exec tends well_dressed and the tweaker tends street.
	var tags := APPEARANCES.keys()
	var picked: Array = []
	for _i in count:
		var weights: Array = []
		var total := 0.0
		for tag in tags:
			if tag in picked:
				weights.append(0.0)
				continue
			var w := 1.0
			for stat in APPEARANCES[tag]:
				w += float(APPEARANCES[tag][stat]) * float(bias.get(stat, 0.0)) * 0.5
			weights.append(w)
			total += w
		var roll := rng.randf() * total
		for j in tags.size():
			roll -= weights[j]
			if roll <= 0.0 and weights[j] > 0.0:
				picked.append(tags[j])
				break
	return picked


## Spend the point-buy pool with weighted-random purchases instead of
## uniform randomness — the allocation tells the same story the body does.
static func allocate_stats(rng: RandomNumberGenerator, bias: Dictionary, appearance: Array) -> Dictionary:
	var stats: Dictionary = {}
	for s in CharacterSheet.STAT_IDS:
		stats[s] = CharacterSheet.STAT_BASE

	var weights: Dictionary = {}
	for s in CharacterSheet.STAT_IDS:
		var w := 1.0 + float(bias.get(s, 0.0))
		for tag in appearance:
			w += float(APPEARANCES.get(tag, {}).get(s, 0.0))
		w += rng.randf_range(0.0, 0.8) # a little chaos, people contain multitudes
		weights[s] = w

	var pool := CharacterSheet.POINT_POOL
	while true:
		var candidates: Array = []
		var total := 0.0
		for s in CharacterSheet.STAT_IDS:
			if stats[s] < CharacterSheet.STAT_CAP \
					and CharacterSheet.step_cost(stats[s]) <= pool:
				candidates.append(s)
				total += weights[s]
		if candidates.is_empty():
			break
		var roll := rng.randf() * total
		for s in candidates:
			roll -= weights[s]
			if roll <= 0.0:
				pool -= CharacterSheet.step_cost(stats[s])
				stats[s] += 1
				break
	return stats


static func pick_traits(rng: RandomNumberGenerator, origin: OriginDef, appearance: Array) -> Array:
	var picked: Array = []
	var all_traits: Array = ContentDB.all_traits()

	var coherence_weight := func(t: TraitDef) -> float:
		var w := 1.0
		for tag in t.coherence_tags:
			if tag in appearance:
				w += 2.5
		return w

	var conflicts_ok := func(t: TraitDef) -> bool:
		if t.id in origin.locked_traits or t.id in origin.free_traits or t.id in picked:
			return false
		for pid in picked:
			var p := ContentDB.get_trait(pid)
			if p and (t.id in p.conflicts_with or pid in t.conflicts_with):
				return false
		return true

	# 1-3 flaws first (they pay for everything, like real life).
	var flaw_count := rng.randi_range(1, 3)
	for _i in flaw_count:
		var pool: Array = all_traits.filter(func(t: TraitDef) -> bool:
			return t.point_cost < 0 and conflicts_ok.call(t))
		if pool.is_empty():
			break
		picked.append(_weighted_pick(rng, pool, coherence_weight).id)

	# Spend the refunds on coherent positives until they don't fit.
	while true:
		var budget := 0
		for tid in picked:
			budget += ContentDB.get_trait(tid).point_cost
		var pool: Array = all_traits.filter(func(t: TraitDef) -> bool:
			return t.point_cost > 0 and t.point_cost <= -budget and conflicts_ok.call(t))
		if pool.is_empty():
			break
		picked.append(_weighted_pick(rng, pool, coherence_weight).id)

	return picked


static func _weighted_pick(rng: RandomNumberGenerator, pool: Array, weight_fn: Callable) -> Variant:
	var total := 0.0
	for item in pool:
		total += weight_fn.call(item)
	var roll := rng.randf() * total
	for item in pool:
		roll -= weight_fn.call(item)
		if roll <= 0.0:
			return item
	return pool.back()


static func random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()],
			LAST_NAMES[rng.randi() % LAST_NAMES.size()]]


static func make_bio(rng: RandomNumberGenerator, name: String, appearance: Array) -> String:
	var age := rng.randi_range(19, 61)
	var desc: String = APPEARANCE_DESCRIPTORS.get(
			appearance[0] if appearance.size() > 0 else "plain", "of no fixed description")
	var hook: String = BIO_HOOKS[rng.randi() % BIO_HOOKS.size()]
	return "%s, %d — %s. %s." % [name.get_slice(" ", 0), age, desc, hook]


## "Deal Me a Life": generate a coherent whole person, respecting locks.
## locks/current keys: "origin", "stats", "traits", "name".
static func deal(locks: Dictionary, current: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var origin: OriginDef
	if locks.get("origin", false) and current.get("origin_id", "") != "":
		origin = ContentDB.get_origin(current.origin_id)
	else:
		var origins: Array = ContentDB.all_origins()
		origin = origins[rng.randi() % origins.size()]

	var appearance := random_appearance(rng, origin.stat_bias)

	var stats: Dictionary
	if locks.get("stats", false) and current.has("base_stats"):
		stats = current.base_stats.duplicate()
	else:
		stats = allocate_stats(rng, origin.stat_bias, appearance)

	var trait_ids: Array
	if locks.get("traits", false) and current.has("trait_ids"):
		trait_ids = current.trait_ids.duplicate()
	else:
		trait_ids = pick_traits(rng, origin, appearance)

	var name: String
	if locks.get("name", false) and current.get("char_name", "") != "":
		name = current.char_name
	else:
		name = random_name(rng)

	return {
		"origin_id": origin.id,
		"base_stats": stats,
		"trait_ids": trait_ids,
		"char_name": name,
		"appearance_tags": appearance,
		"bio": make_bio(rng, name, appearance),
	}
