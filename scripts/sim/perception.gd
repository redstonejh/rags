class_name Perception
extends RefCounted
## The Reality Check engine. NPCs have TRUE hidden stats; the UI shows your
## character's GUESS — appearance stereotypes (the same Coherence table that
## BUILT the NPCs, which is why stereotyping usually works), filtered through
## your INT and Streetwise, inflated by your state (drunk = confident).
## Outcomes always resolve against the truth. The gap is the comedy engine.

## How much of the truth bleeds into the guess: 0.15 (oblivious) - 0.85
## (sharp). People Reader, the top of the tree, simply sees.
static func accuracy(sheet: CharacterSheet) -> float:
	if sheet.has_perk("people_reader"):
		return 1.0
	var a := 0.10 + sheet.get_stat("INT") * 0.02 + sheet.skill_level("streetwise") * 0.06
	return clampf(a, 0.15, 0.85)


## What the player's character THINKS this NPC's stats are.
static func perceived_stats(sheet: CharacterSheet, npc: NPCRecord) -> Dictionary:
	var a := accuracy(sheet)
	var guess := stereotype_stats(npc.appearance_tags)
	var result: Dictionary = {}
	var tripping := int(sheet.flags.get("lsd_minutes", 0)) > 0
	for s in CharacterSheet.STAT_IDS:
		var truth := float(npc.stats.get(s, 8))
		result[s] = roundi(lerpf(float(guess[s]), truth, a))
		if tripping: # the perception system goes fully unreliable
			result[s] = clampi(int(result[s]) + (hash(npc.id + s) % 7) - 3, 3, 18)
	return result


## Pure stereotype: what the appearance ADVERTISES, truth not consulted.
static func stereotype_stats(appearance_tags: Array) -> Dictionary:
	var guess: Dictionary = {}
	for s in CharacterSheet.STAT_IDS:
		var v := 8.0
		for tag in appearance_tags:
			v += float(Coherence.APPEARANCES.get(tag, {}).get(s, 0.0)) * 1.6
		guess[s] = clampi(roundi(v), 6, 15)
	return guess


## Confidence multiplier applied to DISPLAYED odds only. Booze writes checks
## reality doesn't cash; a great mood rounds up.
static func confidence_mult(sheet: CharacterSheet) -> float:
	var m := 1.0
	if int(sheet.flags.get("drunk_minutes", 0)) > 0:
		m *= 1.3
	if sheet.mood() > 80.0:
		m *= 1.1
	return m


static func displayed_chance(sheet: CharacterSheet, perceived: float) -> float:
	return clampf(perceived * confidence_mult(sheet), 0.02, 0.97)


## The Streetwise internal monologue — one read line, quality by skill.
static func read_line(sheet: CharacterSheet, npc: NPCRecord) -> String:
	if sheet.has_perk("people_reader"):
		return "People Reader: %s" % _true_stat_line(npc)
	if int(sheet.flags.get("lsd_minutes", 0)) > 0:
		return _LSD_READS[hash(npc.id) % _LSD_READS.size()]
	var sw := sheet.skill_level("streetwise")
	var tags := npc.appearance_tags
	var first: String = str(tags[0]) if not tags.is_empty() else "plain"
	if sw <= 1:
		return _LOW_READS[hash(npc.id) % _LOW_READS.size()]
	if sw <= 4:
		return "Reads as %s. Probably. You're maybe 60%% sure." % \
				Coherence.APPEARANCE_DESCRIPTORS.get(first, "ordinary")
	# High streetwise smells the subversions — the librarian's knuckles.
	if npc.is_subversion:
		return "Something's off. The %s look doesn't match how they hold their weight. Walk carefully." % first
	return "What you see is what they are: %s. Trust the read." % \
			Coherence.APPEARANCE_DESCRIPTORS.get(first, "ordinary")


static func _true_stat_line(npc: NPCRecord) -> String:
	var parts: Array[String] = []
	for stat in CharacterSheet.STAT_IDS:
		parts.append("%s %d" % [stat, int(npc.stats.get(stat, CharacterSheet.STAT_BASE))])
	return "  ".join(parts)


const _LOW_READS := [
	"They have arms.",
	"A person. Standing there. That's all you've got.",
	"Seems normal? People usually seem normal.",
	"You get no particular feeling about this one.",
]

const _LSD_READS := [
	"Their aura is a parking garage with the lights left on.",
	"This person is mostly water, and the water remembers.",
	"You can see exactly what they were like as a child. Probably.",
	"A cathedral of meat, briefly wearing a name.",
]
