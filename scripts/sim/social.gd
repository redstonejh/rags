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

## Perceived >= this, true <= that, and a failure = a Reality Check moment.
const RC_PERCEIVED_FLOOR := 0.70
const RC_TRUE_CEILING := 0.35

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
	"pickpocket": {"label": "Pickpocket", "roll": true,
		"atk_stat": "DEX", "atk_skill": "stealth", "def_stat": "WIS"},
}


static func available_actions(sheet: CharacterSheet, npc: NPCRecord) -> Array:
	var rel := npc.rel("player")
	var out: Array = []
	for id in ACTIONS:
		var a: Dictionary = ACTIONS[id]
		if rel < float(a.get("min_rel", -1000.0)):
			continue
		if id == "ask_out" and npc.flags.get("dating_player", false):
			continue
		out.append(id)
	if npc.flags.get("dating_player", false):
		out.append("spend_time")
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
	return clampf(0.5 + (atk - def) / 120.0 + rel_bonus, 0.05, 0.95)


## Perform an action. forced_roll in [0,1) makes tests deterministic.
## Returns {success, text, reality_check, perceived, actual}.
static func interact(sheet: CharacterSheet, npc: NPCRecord, action: String, forced_roll := -1.0) -> Dictionary:
	var perceived := perceived_chance(sheet, npc, action)
	var actual := true_chance(sheet, npc, action)
	var roll := forced_roll if forced_roll >= 0.0 else randf()
	var success := roll < actual
	var result := {"success": success, "reality_check": false,
			"perceived": perceived, "actual": actual, "text": ""}

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
		"spend_time":
			GameClock.skip_minutes(60)
			npc.change_rel("player", 4.0)
			sheet.needs.change("social", 20.0)
			sheet.needs.change("fun", 10.0)
			result.text = "An hour disappears the good way."
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
				sheet.dirty_cents += take
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

	# The Reality Check moment: confidence meets fact, fact wins.
	if not success and perceived >= RC_PERCEIVED_FLOOR and actual <= RC_TRUE_CEILING:
		result.reality_check = true
		sheet.needs.change("fun", -12.0)
		sheet.needs.change("social", -8.0)
		_witness_event(sheet, npc,
				"watched the player misjudge %s spectacularly" % npc.display_name, -0.3, 10.0)
		npc.add_memory("embarrassment", "player",
				"misjudged you in public; you put them right", -0.4, 9.0)
		EventBus.reality_check.emit(perceived, actual, npc.id)
		EventBus.toast.emit("The odds in your head re-roll: %d%% becomes %d%%. Everyone saw." % [
				roundi(perceived * 100), roundi(actual * 100)])

	GameClock.skip_minutes(5)
	return result


static func _chat(sheet: CharacterSheet, npc: NPCRecord) -> String:
	npc.change_rel("player", 1.0 + float(npc.personality.get("kindness", 50)) * 0.02)
	sheet.needs.change("social", 8.0)
	# Gossip reaches you: a fresh secondhand memory about you comes up.
	for m in npc.memories:
		if m.get("subject", "") == "player" and m.get("secondhand", false) \
				and float(m.get("salience", 0.0)) >= 3.0:
			return "\"So... I heard you %s. Small town.\"" % str(m.get("text", "did something"))
	var lines := [
		"Weather, work, the price of everything. It helps anyway.",
		"They complain about the diner coffee with real passion.",
		"Five minutes about nothing. You both feel better.",
	]
	return lines[hash(npc.id + str(GameClock.total_minutes)) % lines.size()]


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
