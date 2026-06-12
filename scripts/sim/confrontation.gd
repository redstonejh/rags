class_name Confrontation
extends RefCounted
## The universal standoff system. Every hostile moment freezes into a
## choice — fight / flee / beg / threaten / bribe / comply — resolved by
## relative stats. The odds you SEE are perceived (Perception); the outcome
## uses the truth. Lose a fight you started and YOU do the begging.
##
## Kinds: "carjack" (the flagship gamble — who's in the car?),
## "arrest" (a cop has questions), "standoff_win" (they're begging:
## mercy / rob / kill — the whole town remembers which you picked).

## -> [{id, label, sub}] — sub shows perceived odds or a price.
static func options(kind: String, sheet: CharacterSheet, npc: NPCRecord) -> Array:
	match kind:
		"carjack":
			return [
				{"id": "fight", "label": "Swing anyway",
					"sub": "%d%%" % roundi(_perceived_fight_chance(sheet, npc) * 100)},
				{"id": "bluff", "label": "\"Easy. Wrong car. My mistake.\"",
					"sub": "%d%%" % roundi(Perception.displayed_chance(sheet,
							Social.perceived_chance(sheet, npc, "threaten")) * 100)},
				{"id": "flee", "label": "Run", "sub": "safe-ish"},
				{"id": "beg", "label": "Beg", "sub": "humiliating, effective"},
			]
		"arrest":
			var opts: Array = [
				{"id": "comply", "label": "Hands up (serve %d days)" % CrimeSystem.total_sentence_days(),
					"sub": "the time passes; the town doesn't wait"},
			]
			if CrimeSystem.all_warrants_bailable() \
					and sheet.cash_cents >= CrimeSystem.bail_cents():
				opts.append({"id": "bail", "label": "Post bail ($%d)" % (CrimeSystem.bail_cents() / 100),
						"sub": "money makes it a paperwork problem"})
			opts.append({"id": "flee", "label": "Run for it",
					"sub": "%d%%" % roundi(_flee_chance(sheet, npc) * 100)})
			if npc != null and int(npc.flags.get("corruption", 0)) > 0:
				opts.append({"id": "bribe", "label": "Offer $%d" % (_bribe_cents(sheet) / 100),
						"sub": "depends entirely on the officer"})
			return opts
		"standoff_win":
			return [
				{"id": "mercy", "label": "Let them go", "sub": "they'll remember"},
				{"id": "rob", "label": "Take their wallet", "sub": "they'll REALLY remember"},
				{"id": "kill", "label": "End them", "sub": "the town never forgets a murder"},
			]
	return []


## Resolve a choice. Returns {text, done, follow_up (payload or {}), success}.
static func resolve(kind: String, choice: String, sheet: CharacterSheet,
		npc: NPCRecord, forced_roll := -1.0) -> Dictionary:
	var roll := forced_roll if forced_roll >= 0.0 else CrimeSystem.random_float()
	match kind:
		"carjack":
			return _resolve_carjack(choice, sheet, npc, roll)
		"arrest":
			return _resolve_arrest(choice, sheet, npc, roll)
		"standoff_win":
			return _resolve_standoff_win(choice, sheet, npc)
	return {"text": "...", "done": true, "follow_up": {}, "success": false}


# ------------------------------------------------------------------ fights

static func true_fight_chance(sheet: CharacterSheet, npc: NPCRecord) -> float:
	var atk := sheet.get_stat("STR") * 6.0 + sheet.skill_level("fighting") * 8.0
	var def := float(npc.stats.get("STR", 8)) * 6.0 \
			+ float(npc.personality.get("bravery", 50)) * 0.2
	var perk_bonus := 0.08 if sheet.has_perk("brawler") else 0.0
	return clampf(0.5 + (atk - def) / 120.0 + perk_bonus, 0.05, 0.95)


static func _perceived_fight_chance(sheet: CharacterSheet, npc: NPCRecord) -> float:
	var seen := Perception.perceived_stats(sheet, npc)
	var atk := sheet.get_stat("STR") * 6.0 + sheet.skill_level("fighting") * 8.0
	var def := float(seen.get("STR", 8)) * 6.0 \
			+ float(npc.personality.get("bravery", 50)) * 0.2
	return Perception.displayed_chance(sheet, clampf(0.5 + (atk - def) / 120.0, 0.05, 0.95))


static func _resolve_carjack(choice: String, sheet: CharacterSheet,
		npc: NPCRecord, roll: float) -> Dictionary:
	match choice:
		"fight":
			var perceived := _perceived_fight_chance(sheet, npc)
			var actual := true_fight_chance(sheet, npc)
			var won := roll < actual
			CrimeSystem.commit("assault", WorldState.player_location_id, npc,
					npc.abstract_position(GameClock.total_minutes))
			if won:
				return {"text": "They fold. The car is, suddenly, negotiable.", "done": false,
						"follow_up": {"kind": "standoff_win", "npc_id": npc.id,
							"text": "%s is on the ground, hands up: \"Wait— wait—\"" % npc.display_name},
						"success": true}
			# You started it; you lose it. Reality Check rules apply.
			sheet.needs.change("energy", -35.0)
			sheet.needs.change("fun", -10.0)
			Body.add_wound(sheet, "fracture" if CrimeSystem.roll_chance(0.25) else "bruise")
			if perceived >= Social.RC_PERCEIVED_FLOOR and actual <= Social.RC_TRUE_CEILING:
				EventBus.reality_check.emit(perceived, actual, npc.id)
				EventBus.toast.emit("%d%% became %d%% somewhere around the second punch." % [
						roundi(perceived * 100), roundi(actual * 100)])
			npc.add_memory("fight", "player", "beat you down after you swung first", -0.9, 9.0)
			return {"text": "You wake up on the asphalt. Your jaw files a grievance.",
					"done": true, "follow_up": {}, "success": false}
		"bluff":
			var result := Social.interact(sheet, npc, "threaten", roll)
			return {"text": result.text, "done": true, "follow_up": {}, "success": result.success}
		"flee":
			sheet.needs.change("energy", -10.0)
			npc.add_memory("almost", "player", "tried your car door and bolted", -0.5, 5.0)
			return {"text": "You discover a new personal best in the 400 meters.",
					"done": true, "follow_up": {}, "success": true}
		"beg":
			npc.change_rel("player", -10.0)
			npc.add_memory("begging", "player", "begged your pardon, on its knees", -0.3, 6.0)
			sheet.needs.change("social", -10.0)
			return {"text": "It works. The price was watching yourself do it.",
					"done": true, "follow_up": {}, "success": true}
	return {"text": "...", "done": true, "follow_up": {}, "success": false}


# ------------------------------------------------------------------ arrest

static func _flee_chance(sheet: CharacterSheet, _cop: NPCRecord) -> float:
	return clampf(0.25 + sheet.get_stat("DEX") * 0.02 + sheet.skill_level("fitness") * 0.04, 0.1, 0.8)


static func _bribe_cents(_sheet: CharacterSheet) -> int:
	return maxi(CrimeSystem.wanted_stars(), 1) * 10000


static func _resolve_arrest(choice: String, sheet: CharacterSheet,
		cop: NPCRecord, roll: float) -> Dictionary:
	match choice:
		"comply":
			var days := CrimeSystem.serve_sentence()
			return {"text": _sentence_text(sheet, "You serve %d days." % days),
					"done": true, "follow_up": {}, "success": true}
		"bail":
			if CrimeSystem.pay_bail():
				return {"text": "Money changes hands; the handcuffs become a misunderstanding.",
						"done": true, "follow_up": {}, "success": true}
			return {"text": "You can't cover it. The officer is unmoved.",
					"done": false, "follow_up": {}, "success": false}
		"flee":
			if roll < _flee_chance(sheet, cop):
				sheet.needs.change("energy", -15.0)
				_bump_warrant_evidence(5.0)
				return {"text": "You vanish through the alley. Somewhere behind you, a radio crackles.",
						"done": true, "follow_up": {}, "success": true}
			_bump_warrant_evidence(10.0)
			var days := CrimeSystem.serve_sentence()
			return {"text": _sentence_text(sheet,
					"Tackled in twenty meters. Resisting added paperwork. %d days." % days),
					"done": true, "follow_up": {}, "success": false}
		"bribe":
			var price := _bribe_cents(sheet)
			if sheet.cash_cents < price:
				return {"text": "Your wallet makes the offer embarrassing. The cuffs come out.",
						"done": false, "follow_up": {}, "success": false}
			if int(cop.flags.get("corruption", 0)) >= 50:
				sheet.add_cash(-price)
				cop.flags["bribed_until_day"] = GameClock.day + 1
				return {"text": "Officer %s develops sudden, profound amnesia. Expensive amnesia." % cop.display_name,
						"done": true, "follow_up": {}, "success": true}
			CrimeSystem.commit("bribery", WorldState.player_location_id, cop)
			var days := CrimeSystem.serve_sentence()
			return {"text": _sentence_text(sheet,
					"Wrong cop. The bribe becomes a charge, the charge becomes %d days." % days),
					"done": true, "follow_up": {}, "success": false}
	return {"text": "...", "done": true, "follow_up": {}, "success": false}


static func _sentence_text(sheet: CharacterSheet, lead: String) -> String:
	var parts := [lead]
	var event_text := CrimeSystem.jail_event_summary(sheet.flags.get("last_jail_events", []))
	if event_text != "":
		parts.append("Jail days: %s." % event_text)
	var contact_text := CrimeSystem.jail_contact_summary(sheet.flags.get("last_jail_contacts", []))
	if contact_text != "":
		parts.append("Inside: %s." % contact_text)
	var consequence_text := CrimeSystem.jail_consequence_summary(
			sheet.flags.get("last_jail_consequences", {}))
	if consequence_text != "":
		parts.append("Outside: %s." % consequence_text)
	return " ".join(parts)


static func _bump_warrant_evidence(amount: float) -> void:
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			case.evidence = clampf(case.evidence + amount, 0.0, 100.0)


# ------------------------------------------------------ they're begging now

static func _resolve_standoff_win(choice: String, sheet: CharacterSheet,
		npc: NPCRecord) -> Dictionary:
	match choice:
		"mercy":
			npc.change_rel("player", 5.0) # fear and gratitude, in one
			npc.add_memory("mercy", "player", "beat you fair and let you walk", -0.1, 7.0)
			return {"text": "They scramble off. Mercy is cheap and they'll remember it anyway.",
					"done": true, "follow_up": {}, "success": true}
		"rob":
			var take: int = mini(npc.money_cents, 2000 + npc.money_cents / 4)
			npc.money_cents -= take
			sheet.add_dirty_cash(take)
			CrimeSystem.commit("armed_robbery", WorldState.player_location_id, npc,
					npc.abstract_position(GameClock.total_minutes))
			return {"text": "$%.2f, still warm. They memorize your face the whole time." % (take / 100.0),
					"done": true, "follow_up": {}, "success": true}
		"kill":
			var scene := npc.abstract_position(GameClock.total_minutes)
			kill_npc(npc, "beaten to death")
			CrimeSystem.commit("murder", WorldState.player_location_id, null, scene)
			sheet.needs.change("fun", -20.0)
			sheet.needs.change("social", -10.0)
			return {"text": "It's quiet after. %s doesn't get up. The town will not forget this." % npc.display_name,
					"done": true, "follow_up": {}, "success": true}
	return {"text": "...", "done": true, "follow_up": {}, "success": false}


## Death is permanent for NPCs too. The record stays — the town remembers —
## but the person stops. Their job is open now; somebody will mention that.
static func kill_npc(npc: NPCRecord, cause: String) -> void:
	npc.alive = false
	npc.current_activity = "dead"
	SimEngine.despawn_npc(npc)
	EventBus.npc_died.emit(npc.id, cause)
