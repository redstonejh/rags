class_name Social
extends RefCounted
## The social interaction resolver. Every action shows PERCEIVED odds
## (Perception) but resolves against TRUE stats. A hard miss — you were
## confident and reality wasn't — fires a Reality Check moment: mood hit,
## witnesses, gossip that outlives you.
##
## Pure static functions over records so headless tests can drive everything.

const REL_MIN := -100.0
const REL_MAX := 100.0
const ODDS_SPREAD := 140.0

## Perceived >= this, true <= that, and a failure = a Reality Check moment.
const RC_PERCEIVED_FLOOR := 0.70
const RC_TRUE_CEILING := 0.35
const PICKPOCKET_DISTRACTION_BONUS := 0.08
const PICKPOCKET_SLEEPING_BONUS := 0.20
const PICKPOCKET_FOUNDER_DAY_BONUS := 0.10
const PICKPOCKET_EYE_PENALTY := 0.03
const PICKPOCKET_COP_EYE_PENALTY := 0.08
const PICKPOCKET_MAX_EYE_PENALTY := 0.18
const PICKPOCKET_DISTRACTED_ACTIVITIES := [
	"shopping", "drinking", "eating", "loitering", "wandering", "working", "date",
]

const ACTIONS := {
	"chat": {"label": "Chat", "roll": false},
	"compliment": {"label": "Compliment", "roll": true,
		"atk_stat": "CHA", "atk_skill": "persuasion", "def_stat": "WIS"},
	"joke": {"label": "Tell a joke", "roll": true,
		"atk_stat": "CHA", "atk_skill": "persuasion", "def_stat": "WIS"},
	"flirt": {"label": "Flirt", "roll": true, "min_rel": 15.0,
		"atk_stat": "CHA", "atk_skill": "persuasion", "def_stat": "WIS"},
	"ask_out": {"label": "Ask out", "roll": true, "min_rel": 40.0,
		"atk_stat": "CHA", "atk_skill": "persuasion", "def_stat": "WIS"},
	"insult": {"label": "Insult", "roll": false},
	"threaten": {"label": "Threaten", "roll": true,
		"atk_stat": "STR", "atk_skill": "streetwise", "def_stat": "STR", "def_bravery": true},
	"intimidate_witness": {"label": "Lean on witness", "roll": true,
		"atk_stat": "STR", "atk_skill": "streetwise", "def_stat": "STR", "def_bravery": true},
	"pickpocket": {"label": "Pickpocket", "roll": true,
		"atk_stat": "DEX", "atk_skill": "stealth", "def_stat": "WIS"},
	"date_mels": {"label": "Date: meal at Mel's", "roll": false},
	"date_anchor": {"label": "Date: drink at the Anchor", "roll": false},
	"propose": {"label": "Propose", "roll": true, "min_rel": 70.0,
		"atk_stat": "CHA", "atk_skill": "persuasion", "def_stat": "WIS"},
	"try_for_baby": {"label": "Try for a baby", "roll": false},
}

const DATE_SCENES := {
	"date_mels": {
		"title": "Mel's Diner",
		"prompt": "Mel's gives you a booth by the window. The coffee is bitter, the plates are chipped, and nobody is in a hurry.",
		"choices": [
			{"id": "date_mels_listen", "label": "Ask about their week"},
			{"id": "date_mels_joke", "label": "Make booth jokes"},
			{"id": "date_mels_future", "label": "Talk future plans"},
		],
	},
	"date_anchor": {
		"title": "The Rusty Anchor",
		"prompt": "The Anchor is loud enough to make honesty feel private. The jukebox keeps picking fights with the room.",
		"choices": [
			{"id": "date_anchor_round", "label": "Buy the next round"},
			{"id": "date_anchor_corner", "label": "Find a quiet corner"},
			{"id": "date_anchor_darts", "label": "Play darts badly"},
		],
	},
}


static func is_date_scene(action: String) -> bool:
	return DATE_SCENES.has(action)


static func date_scene(action: String) -> Dictionary:
	return DATE_SCENES.get(action, {})


static func available_actions(sheet: CharacterSheet, npc: NPCRecord) -> Array:
	var rel := npc.rel("player")
	var out: Array = []
	for id in ACTIONS:
		if id in ["date_mels", "date_anchor", "propose", "try_for_baby"]:
			continue # appended below, gated on the relationship stage
		var a: Dictionary = ACTIONS[id]
		if rel < float(a.get("min_rel", -1000.0)):
			continue
		if id == "intimidate_witness" and _witness_case_id(npc) == "":
			continue
		if id == "ask_out" and npc.flags.get("dating_player", false):
			continue
		out.append(id)
	if npc.flags.get("dating_player", false):
		out.append("date_mels")
		out.append("date_anchor")
		if rel >= 70.0 and not npc.flags.get("married_to_player", false):
			out.append("propose")
	if npc.flags.get("married_to_player", false) \
			and not sheet.flags.has("pregnant_due_day"):
		out.append("try_for_baby")
	return out


## True chance, resolved against the target's REAL stats.
static func true_chance(sheet: CharacterSheet, npc: NPCRecord, action: String) -> float:
	return _chance(sheet, npc, action, npc.stats)


## What the player's UI shows — same formula, perceived stats, confidence-inflated.
static func perceived_chance(sheet: CharacterSheet, npc: NPCRecord, action: String) -> float:
	var stats := Perception.perceived_stats(sheet, npc)
	return Perception.displayed_chance(sheet, _chance(sheet, npc, action, stats))


static func _chance(sheet: CharacterSheet, npc: NPCRecord, action: String, def_stats: Dictionary) -> float:
	var a: Dictionary = ACTIONS.get(action, {})
	if not a.get("roll", false):
		return 1.0
	var atk := sheet.get_stat(str(a.atk_stat)) * 6.0 \
			+ sheet.skill_level(str(a.get("atk_skill", ""))) * 8.0
	var def := float(def_stats.get(str(a.def_stat), 8)) * 6.0
	if a.get("def_bravery", false):
		def += float(npc.personality.get("bravery", 50)) * 0.4
	var rel_bonus := npc.rel("player") * 0.002
	var perk_bonus := 0.05 if sheet.has_perk("silver_tongue") else 0.0
	var context_bonus := pickpocket_context_modifier(npc) if action == "pickpocket" else 0.0
	return clampf(0.5 + (atk - def) / ODDS_SPREAD + rel_bonus + perk_bonus + context_bonus,
			0.05, 0.95)


static func pickpocket_context_modifier(npc: NPCRecord) -> float:
	var modifier := 0.0
	if npc.current_activity == "sleeping":
		modifier += PICKPOCKET_SLEEPING_BONUS
	elif npc.current_activity in PICKPOCKET_DISTRACTED_ACTIVITIES:
		modifier += PICKPOCKET_DISTRACTION_BONUS
	if TownLife.holiday_today() == "FOUNDER'S DAY":
		modifier += PICKPOCKET_FOUNDER_DAY_BONUS
	var witnesses := _pickpocket_nearby_eyes(npc)
	var eye_penalty := 0.0
	for witness in witnesses:
		eye_penalty += PICKPOCKET_COP_EYE_PENALTY if witness.is_cop() else PICKPOCKET_EYE_PENALTY
	modifier -= minf(eye_penalty, PICKPOCKET_MAX_EYE_PENALTY)
	return modifier


static func _pickpocket_nearby_eyes(target: NPCRecord) -> Array:
	var out: Array = []
	var now := GameClock.total_minutes
	var scene := target.abstract_position(now)
	for npc in WorldState.npcs.values():
		if npc == target or not npc.alive or npc.current_activity == "sleeping":
			continue
		if npc.current_location_id != target.current_location_id:
			continue
		if target.current_location_id == "exterior" \
				and npc.abstract_position(now).distance_to(scene) > CrimeSystem.EXTERIOR_WITNESS_RADIUS:
			continue
		out.append(npc)
	return out


## Perform an action. forced_roll in [0,1) makes tests deterministic.
## Returns {success, text, reality_check, perceived, actual}.
static func interact(sheet: CharacterSheet, npc: NPCRecord, action: String, forced_roll := -1.0) -> Dictionary:
	var perceived := perceived_chance(sheet, npc, action)
	var actual := true_chance(sheet, npc, action)
	var roll := forced_roll if forced_roll >= 0.0 else _randf()
	if forced_roll < 0.0 and sheet.has_tag("luck"):
		roll = minf(roll, _randf()) # the Gambler's whole deal: roll twice, keep the better
	var success := roll < actual
	if success and ACTIONS.get(action, {}).get("roll", false):
		sheet.add_xp(3)
	var result := {"success": success, "reality_check": false,
			"perceived": perceived, "actual": actual, "text": ""}
	var date_location := ""

	match action:
		"chat":
			result.text = _chat(sheet, npc)
		"compliment":
			result.text = _apply(sheet, npc, success,
					6.0, "compliment", 0.4, 3.0, "\"...thanks?\" They mean it.",
					-2.0, "It lands like a wet napkin.")
		"joke":
			if success:
				sheet.needs.change("fun", 8.0)
			result.text = _apply(sheet, npc, success,
					5.0, "joke", 0.4, 3.0, "A real laugh. People glance over.",
					-3.0, "Silence. A car alarm, somewhere, takes pity.")
		"flirt":
			result.text = _apply(sheet, npc, success,
					8.0, "flirt", 0.6, 4.0, "They tuck their hair back. Noted.",
					-5.0, "\"I have somewhere to be.\" They did not, until now.")
		"ask_out":
			if success:
				npc.flags["dating_player"] = true
				sheet.needs.change("social", 25.0)
				npc.change_rel("player", 15.0)
				npc.add_memory("date", "player", "said yes to a date with you", 1.0, 7.0)
				result.text = "\"Yeah. Okay. Yes.\" The town feels briefly less gray."
			else:
				npc.change_rel("player", -8.0)
				npc.add_memory("rejection", "player", "turned you down", -0.4, 5.0)
				result.text = "\"Oh. Oh no. I'm— flattered?\" The worst sentence in English."
		"date_mels":
			date_location = "loc_diner"
			result.text = _date_activity(sheet, npc, "loc_diner", 90, 6.0, 18.0, 8.0,
					"shared a booth with you at Mel's",
					"Mel's gives you the corner booth. Pancakes, burnt coffee, and no urgent disasters.")
		"date_anchor":
			date_location = "loc_bar"
			result.text = _date_activity(sheet, npc, "loc_bar", 120, 4.0, 14.0, 16.0,
					"had drinks with you at the Rusty Anchor",
					"The Anchor is loud enough to make honesty feel private. It works, mostly.")
		"date_mels_listen":
			date_location = "loc_diner"
			result.text = _date_activity(sheet, npc, "loc_diner", 90, 8.0, 24.0, 5.0,
					"felt heard over pancakes at Mel's",
					"You let them talk until the coffee goes cold. It is cheaper than therapy and more useful.",
					"listen")
		"date_mels_joke":
			date_location = "loc_diner"
			result.text = _date_activity(sheet, npc, "loc_diner", 90, 5.0, 16.0, 14.0,
					"laughed with you in a Mel's booth",
					"The booth becomes a two-person comedy club. The waitress does not tip you back.",
					"joke")
		"date_mels_future":
			date_location = "loc_diner"
			result.text = _date_activity(sheet, npc, "loc_diner", 90, 6.0, 18.0, 6.0,
					"talked future plans with you at Mel's",
					"You talk about next week like rent, weather, and fate can be negotiated.",
					"future")
		"date_anchor_round":
			date_location = "loc_bar"
			result.text = _date_activity(sheet, npc, "loc_bar", 120, 4.0, 14.0, 18.0,
					"had a round with you at the Rusty Anchor",
					"The next round buys warmth, noise, and a mercifully blurry memory of the bill.",
					"round")
		"date_anchor_corner":
			date_location = "loc_bar"
			result.text = _date_activity(sheet, npc, "loc_bar", 120, 8.0, 24.0, 8.0,
					"shared a quiet corner with you at the Rusty Anchor",
					"You find the least sticky corner and talk like the rest of the bar is weather.",
					"corner")
		"date_anchor_darts":
			date_location = "loc_bar"
			result.text = _date_activity(sheet, npc, "loc_bar", 120, 5.0, 16.0, 20.0,
					"played darts with you at the Rusty Anchor",
					"You both learn that confidence and aim are separate skill trees.",
					"darts")
		"propose":
			if success:
				npc.flags["married_to_player"] = true
				sheet.flags["spouse_id"] = npc.id
				npc.home_id = "loc_bricks" # they move in; the Bricks gains a romance
				npc.change_rel("player", 20.0)
				npc.add_memory("wedding", "player", "married you at the courthouse, twenty minutes, no music", 1.0, 9.0)
				sheet.needs.change("social", 40.0)
				result.text = "\"Yes.\" The courthouse charges $20 and doesn't validate parking. Married."
			else:
				npc.change_rel("player", -12.0)
				npc.add_memory("rejection", "player", "proposed and got a 'not yet'", -0.3, 7.0)
				result.text = "\"...not yet.\" The ring goes back in the sock drawer."
		"try_for_baby":
			GameClock.skip_minutes(60)
			sheet.needs.change("social", 15.0)
			if roll < 0.35:
				sheet.flags["pregnant_due_day"] = GameClock.day + 7
				result.text = "A few weeks later: two pink lines. The math starts immediately."
			else:
				result.text = "Nature takes its time. Nature has no rent due."
		"insult":
			npc.change_rel("player", -15.0)
			npc.add_memory("insult", "player", "insulted you to your face", -0.8, 6.0)
			sheet.needs.change("fun", 3.0) # being awful is, briefly, fun
			result.text = "You say the thing. It cannot be unsaid."
			_witness_event(sheet, npc, "watched the player tear into %s" % npc.display_name, -0.4, 4.0)
		"pickpocket":
			if success:
				var take: int = clampi(npc.money_cents / 10, 500, 4500)
				take = mini(take, npc.money_cents)
				npc.money_cents -= take
				sheet.add_dirty_cash(take)
				sheet.add_skill_xp("stealth", 2.0)
				result.text = "$%.2f migrates pockets. Nobody felt a thing." % (take / 100.0)
			else:
				CrimeSystem.commit("pickpocket", npc.current_location_id, npc,
						npc.abstract_position(GameClock.total_minutes))
				result.text = "Your hand is in their coat when they turn around. Words are exchanged. Loud ones."
		"threaten":
			if success:
				npc.change_rel("player", -20.0)
				npc.flags["scared_of_player_until_day"] = GameClock.day + 2
				npc.add_memory("threat", "player", "threatened you and meant it", -0.9, 8.0)
				result.text = "They go pale and very agreeable."
				_witness_event(sheet, npc, "saw the player back %s down" % npc.display_name, -0.5, 6.0)
			else:
				npc.change_rel("player", -10.0)
				sheet.needs.change("energy", -8.0)
				npc.add_memory("threat_failed", "player", "tried to threaten you; it went badly for them", -0.5, 7.0)
				result.text = "They look down at you — when did they get taller? — and shove you into next week."

		"intimidate_witness":
			var case_id := _witness_case_id(npc)
			if success and case_id != "":
				npc.change_rel("player", -25.0)
				npc.add_memory("witness_intimidated", "player",
						"leaned on you about what you saw", -0.95, 9.0)
				var suppressed := CrimeSystem.suppress_witness_report(npc, case_id)
				result.text = "They suddenly remember less. The case file gets thinner." \
						if suppressed else "They nod too fast. Fear lands; the paperwork barely moves."
			else:
				npc.change_rel("player", -15.0)
				npc.add_memory("witness_intimidation_failed", "player",
						"tried to scare you out of talking", -0.8, 9.0)
				CrimeSystem.commit("witness_intimidation", npc.current_location_id, npc,
						npc.abstract_position(GameClock.total_minutes))
				result.text = "Wrong witness. The coverup becomes its own charge."

	# The Reality Check moment: confidence meets fact, fact wins.
	if not success and perceived >= RC_PERCEIVED_FLOOR and actual <= RC_TRUE_CEILING:
		result.reality_check = true
		sheet.needs.change("fun", -12.0)
		sheet.needs.change("social", -8.0)
		_witness_event(sheet, npc,
				"saw you misjudge %s" % npc.display_name, -0.3, 10.0)
		npc.flags["reacting_until_min"] = GameClock.total_minutes + 20
		npc.flags["reaction_target_id"] = "player"
		npc.flags["reaction_kind"] = "called_out"
		npc.add_memory("embarrassment", "player",
				"misjudged you in public; you put them right", -0.4, 9.0)
		EventBus.reality_check.emit(perceived, actual, npc.id)
		EventBus.toast.emit("The odds in your head re-roll: %d%% becomes %d%%. Everyone saw." % [
				roundi(perceived * 100), roundi(actual * 100)])

	GameClock.skip_minutes(5)
	if date_location != "":
		WorldState.player_location_id = date_location
		npc.current_location_id = date_location
		npc.current_activity = "date"
		npc.traveling = false
	return result


static func _chat(sheet: CharacterSheet, npc: NPCRecord) -> String:
	npc.change_rel("player", 1.0 + float(npc.personality.get("kindness", 50)) * 0.02)
	sheet.needs.change("social", 8.0)
	# Gossip reaches you: a fresh secondhand memory about you comes up.
	for m in npc.memories:
		if m.get("subject", "") == "player" and m.get("secondhand", false) \
				and float(m.get("salience", 0.0)) >= 3.0:
			return "\"So... %s that you %s. %s\"" % [
				_gossip_source_chain(m),
				str(m.get("text", "did something")),
				_gossip_source_flavor(npc, str(m.get("source_id", "")))]
	var lines := [
		"Weather, work, the price of everything. It helps anyway.",
		"They complain about the diner coffee with real passion.",
		"Five minutes about nothing. You both feel better.",
	]
	return lines[hash(npc.id + str(GameClock.total_minutes)) % lines.size()]


static func _gossip_source_name(source_id: String) -> String:
	var source: NPCRecord = WorldState.npcs.get(source_id)
	return source.display_name if source != null else "someone"


static func _gossip_source_chain(memory: Dictionary) -> String:
	var source_id := str(memory.get("source_id", ""))
	var previous_id := str(memory.get("previous_source_id", ""))
	if previous_id != "" and previous_id != source_id:
		return "%s heard from %s" % [
			_gossip_source_name(source_id),
			_gossip_source_name(previous_id)]
	return "%s said" % _gossip_source_name(source_id)


static func _gossip_source_flavor(listener: NPCRecord, source_id: String) -> String:
	var source: NPCRecord = WorldState.npcs.get(source_id)
	if source == null:
		return "Small town."
	var rel := listener.rel(source_id)
	if source.is_cop():
		return "Cops gossip like everybody else."
	if rel >= 35.0:
		return "I believe them, which is inconvenient for you."
	if rel <= -35.0:
		return "I hate that I believe them."
	return "Small town."


static func _apply(sheet: CharacterSheet, npc: NPCRecord, success: bool,
		win_rel: float, kind: String, tone: float, salience: float, win_text: String,
		lose_rel: float, lose_text: String) -> String:
	if success:
		npc.change_rel("player", win_rel)
		npc.add_memory(kind, "player", "%s went over well" % kind, tone, salience)
		sheet.needs.change("social", 5.0)
		return win_text
	npc.change_rel("player", lose_rel)
	return lose_text


static func _date_activity(sheet: CharacterSheet, npc: NPCRecord, location_id: String,
		minutes: int, rel_gain: float, social_gain: float, fun_gain: float,
		memory_text: String, result_text: String, date_style := "") -> String:
	if WorldState.player_location_id != location_id:
		EventBus.travel_requested.emit(location_id)
	GameClock.skip_minutes(minutes)
	var adjustment := _date_personality_adjustment(npc, date_style)
	WorldState.player_location_id = location_id
	npc.current_location_id = location_id
	npc.current_activity = "date"
	npc.traveling = false
	npc.change_rel("player", rel_gain + float(adjustment.get("rel", 0.0)))
	sheet.needs.change("social", social_gain + float(adjustment.get("social", 0.0)))
	sheet.needs.change("fun", fun_gain + float(adjustment.get("fun", 0.0)))
	npc.add_memory("date", "player", memory_text + str(adjustment.get("memory_suffix", "")), 0.7, 6.5)
	var note := str(adjustment.get("note", ""))
	return "%s %s" % [result_text, note] if note != "" else result_text


static func _date_personality_adjustment(npc: NPCRecord, date_style: String) -> Dictionary:
	match date_style:
		"listen":
			if _personality(npc, "chattiness") >= 65:
				return {"rel": 2.0, "social": 4.0,
						"note": "They had more to say than they expected.",
						"memory_suffix": "; you let them talk"}
			if _personality(npc, "chattiness") <= 25:
				return {"rel": 1.0,
						"note": "They appreciate that you do not pry when the answer gets short.",
						"memory_suffix": "; you did not push"}
		"joke":
			if _personality(npc, "chattiness") >= 60 or _personality(npc, "kindness") >= 65:
				return {"rel": 2.0, "fun": 4.0,
						"note": "Their laugh arrives first and stays late.",
						"memory_suffix": "; the jokes landed"}
			if _personality(npc, "kindness") <= 30:
				return {"rel": -1.0, "fun": -2.0,
						"note": "They smile politely, which is worse.",
						"memory_suffix": "; the jokes did not land"}
		"future":
			if _personality(npc, "kindness") >= 65 and _personality(npc, "jealousy") <= 55:
				return {"rel": 2.0, "social": 2.0,
						"note": "They start using 'we' and pretend not to notice.",
						"memory_suffix": "; the future sounded possible"}
			if _personality(npc, "jealousy") >= 70:
				return {"rel": -2.0, "social": -3.0,
						"note": "The future talk trips a wire they do not name.",
						"memory_suffix": "; future talk made them guarded"}
		"round":
			if str(npc.flags.get("vice", "")) == "booze":
				return {"rel": 1.0, "fun": 5.0,
						"note": "They know exactly what to order and exactly why.",
						"memory_suffix": "; you remembered their drink"}
			if _personality(npc, "greed") <= 25:
				return {"rel": 1.0,
						"note": "They notice the gesture more than the tab.",
						"memory_suffix": "; you bought the round"}
		"corner":
			if _personality(npc, "chattiness") <= 35 or _personality(npc, "kindness") >= 70:
				return {"rel": 2.0, "social": 4.0,
						"note": "The quieter table does more work than the music ever could.",
						"memory_suffix": "; the quiet helped"}
		"darts":
			if _personality(npc, "bravery") >= 65:
				return {"rel": 2.0, "fun": 4.0,
						"note": "They play to win, then like you better for trying.",
						"memory_suffix": "; the darts got competitive"}
			if _personality(npc, "bravery") <= 25:
				return {"rel": -1.0, "fun": -2.0,
						"note": "They laugh, but only after the sharp things are back on the wall.",
						"memory_suffix": "; darts were a lot"}
	return {}


static func _personality(npc: NPCRecord, key: String) -> int:
	return int(npc.personality.get(key, 50))


static func _witness_case_id(npc: NPCRecord) -> String:
	var best_day := -999999
	var best_case_id := ""
	for memory in npc.memories:
		if memory.get("kind", "") != "crime" or memory.get("subject", "") != "player":
			continue
		if int(memory.get("suppressed_until_day", -1)) >= GameClock.day:
			continue
		var case_id := str(memory.get("case_id", ""))
		var case: CrimeCase = WorldState.crime_cases.get(case_id)
		if case == null or case.status in [CrimeCase.CLOSED, CrimeCase.COLD]:
			continue
		var memory_day := int(memory.get("day", -999999))
		if memory_day >= best_day:
			best_day = memory_day
			best_case_id = case_id
	return best_case_id


## Everyone else in the room remembers what they saw. Outside, only people
## actually near the scene count — the street is big.
static func _witness_event(_sheet: CharacterSheet, target: NPCRecord,
		text: String, tone: float, salience: float) -> void:
	var now := GameClock.total_minutes
	var scene := target.abstract_position(now)
	for npc in WorldState.npcs.values():
		if npc == target or not npc.alive or npc.current_activity == "sleeping":
			continue
		if npc.current_location_id != target.current_location_id:
			continue
		if target.current_location_id == "exterior" \
				and npc.abstract_position(now).distance_to(scene) > 320.0:
			continue
		npc.add_memory("witnessed", "player", text, tone, salience)
		npc.change_rel("player", tone * 3.0)
		npc.flags["reacting_until_min"] = now + 20
		npc.flags["reaction_target_id"] = target.id
		npc.flags["reaction_kind"] = "witnessed"


static func _randf() -> float:
	var rng := RandomNumberGenerator.new()
	if WorldState.social_rng_state == 0:
		WorldState.reset_social_rng()
	rng.seed = WorldState.social_rng_seed
	rng.state = WorldState.social_rng_state
	var value := rng.randf()
	WorldState.social_rng_state = rng.state
	return value
