class_name Body
extends RefCounted
## The body keeps the receipts: substances (tolerance/addiction/overdose),
## wounds that heal badly if untreated, teeth, aging, pregnancy, and the
## slow arithmetic of a whole life. Static functions over the sheet;
## EconomySystem drives the daily tick.

const DAYS_PER_YEAR := 5.0           # 5 game days = 1 year of life
const ELDER_AGE := 70.0
const ADDICTION_CRAVING_THRESHOLD := 0.3
const RECOVERY_CHIP_DAYS := [3, 7, 30] # detox, the hard week, the chip
const TEETH_FULL := 32

## Wound kinds: days to heal, stat dragged while open, permanent flag if
## it heals untreated ("" = heals clean either way).
const WOUNDS := {
	"bruise": {"days": 3, "stat": "STR", "perm": ""},
	"cut": {"days": 5, "stat": "", "perm": "scarred"},
	"fracture": {"days": 14, "stat": "DEX", "perm": "crooked_arm"},
}


static func roll_chance(chance: float) -> bool:
	return _randf() < clampf(chance, 0.0, 1.0)


# ------------------------------------------------------------- substances

static func substance_state(sheet: CharacterSheet, id: String) -> Dictionary:
	if not sheet.substances.has(id):
		sheet.substances[id] = {"tolerance": 0.0, "addiction": 0.0,
				"last_use_day": -999, "clean_days": 0}
	return sheet.substances[id]


## One dose: effects shrink with tolerance; addiction and the ledger grow.
## Returns a result text (overdoses narrate themselves).
static func use_substance(sheet: CharacterSheet, id: String) -> String:
	var def := ContentDB.get_substance(id)
	if def == null:
		return ""
	var state := substance_state(sheet, id)
	var potency := clampf(1.0 - float(state.tolerance) * 0.5, 0.3, 1.0)
	for need_id in def.need_effects:
		var amount := float(def.need_effects[need_id]) * potency
		if need_id == "craving":
			sheet.needs.add_optional("craving")
			amount = float(def.need_effects[need_id]) # the Need is always fully fed
		sheet.needs.change(need_id, amount)
	var liver := 0.5 if sheet.has_perk("iron_liver") else 1.0
	state.tolerance = minf(float(state.tolerance) + def.tolerance_per_use * liver, 1.0)
	state.addiction = minf(float(state.addiction) + def.addiction_per_use, 1.0)
	state.last_use_day = GameClock.day
	state.clean_days = 0
	if float(state.addiction) >= ADDICTION_CRAVING_THRESHOLD:
		sheet.needs.add_optional("craving")
	# The confidence lie, while it lasts.
	if def.confidence_mult > 1.0:
		sheet.flags["drunk_minutes"] = maxi(int(sheet.flags.get("drunk_minutes", 0)), def.duration_minutes)
	if id == "lsd":
		sheet.flags["lsd_minutes"] = def.duration_minutes
	if def.tooth_risk > 0.0 and _randf() < def.tooth_risk:
		sheet.flags["teeth"] = maxi(int(sheet.flags.get("teeth", TEETH_FULL)) - 1, 0)
	# Overdose: scaled by addiction; xanax + alcohol is the famous mistake.
	var od := def.overdose_chance * (1.0 + float(state.addiction) * 2.0)
	if def.deadly_with_alcohol and int(sheet.flags.get("drunk_minutes", 0)) > 0:
		od += 0.25
	if od > 0.0 and _randf() < od:
		return _overdose(sheet)
	return "The %s lands. %s" % [def.display_name.to_lower(),
			"Tolerance is winning, though." if potency < 0.7 else "For a while, everything is negotiable."]


static func _overdose(sheet: CharacterSheet) -> String:
	GameClock.skip_minutes(12 * 60)
	sheet.needs.change("energy", -80.0)
	sheet.needs.change("hygiene", -40.0)
	var robbed: int = sheet.cash_cents / 2
	sheet.add_cash(-robbed)
	EventBus.toast.emit("You wake up twelve hours later, half your cash gone, all of your dignity.")
	return "Too much. The ground came up to meet you."


## Heaviest addiction on the sheet (drives the Recovery path).
static func worst_addiction(sheet: CharacterSheet) -> Dictionary:
	var worst := {"id": "", "addiction": 0.0, "clean_days": 0}
	for id in sheet.substances:
		var s: Dictionary = sheet.substances[id]
		if float(s.addiction) > float(worst.addiction):
			worst = {"id": id, "addiction": float(s.addiction), "clean_days": int(s.clean_days)}
	return worst


# ------------------------------------------------------------------ wounds

static func add_wound(sheet: CharacterSheet, kind: String) -> void:
	var spec: Dictionary = WOUNDS.get(kind, WOUNDS["bruise"])
	sheet.wounds.append({"kind": kind, "days_left": int(spec.days), "treated": false})
	EventBus.toast.emit("Wound: %s. It'll heal. The question is how." % kind)


static func treat_wounds(sheet: CharacterSheet) -> int:
	var count := 0
	for w in sheet.wounds:
		if not w.treated:
			w.treated = true
			w.days_left = mini(int(w.days_left), 2)
			count += 1
	return count


## While a wound is open, it drags its stat (read by get_stat).
static func wound_stat_penalty(sheet: CharacterSheet, stat: String) -> int:
	var penalty := 0
	for w in sheet.wounds:
		var spec: Dictionary = WOUNDS.get(str(w.kind), {})
		if spec.get("stat", "") == stat:
			penalty -= 1
	return penalty


# ------------------------------------------------------------- daily tick

## Called by EconomySystem on day_passed, before the calorie math.
static func daily_tick(sheet: CharacterSheet) -> void:
	# Substances: clean days accrue; old addictions fade glacially.
	for id in sheet.substances:
		var s: Dictionary = sheet.substances[id]
		if int(s.last_use_day) < GameClock.day:
			s.clean_days = int(s.clean_days) + 1
			s.addiction = maxf(float(s.addiction) - 0.005, 0.0)
			s.tolerance = maxf(float(s.tolerance) - 0.02, 0.0)
			if int(s.clean_days) in RECOVERY_CHIP_DAYS:
				EventBus.toast.emit("%d days clean of %s. The chip is plastic; what it stands for isn't." % [
						int(s.clean_days), id])
				EventBus.path_updated.emit()
	# Wounds heal — badly, if nobody looked at them.
	var still_open: Array = []
	for w in sheet.wounds:
		w.days_left = int(w.days_left) - 1
		if int(w.days_left) > 0:
			still_open.append(w)
			continue
		var spec: Dictionary = WOUNDS.get(str(w.kind), {})
		var perm := str(spec.get("perm", ""))
		if perm != "" and not w.treated:
			if perm == "scarred":
				sheet.flags["scars"] = int(sheet.flags.get("scars", 0)) + 1
				EventBus.toast.emit("The cut closes into a scar. People will ask. You'll lie.")
			else:
				sheet.flags[perm] = true
				EventBus.toast.emit("It healed wrong. Some things you only get one of.")
	sheet.wounds = still_open
	# Aging. Everyone's doing it; you're just doing it on a schedule.
	sheet.age_years += 1.0 / DAYS_PER_YEAR
	if sheet.age_years >= ELDER_AGE and sheet.alive:
		var risk := 0.01 + (sheet.age_years - ELDER_AGE) * 0.004
		if _randf() < risk:
			EventBus.player_died.emit("old age")
			return
	# Going Straight: stay warrant-free long enough and The Record seals.
	if sheet.has_tag("the_record") and not sheet.flags.get("record_sealed", false):
		var last := int(sheet.flags.get("last_warrant_day", int(sheet.flags.get("parole_start_day", 0))))
		if GameClock.day - maxi(last, int(sheet.flags.get("parole_start_day", 0))) >= 14:
			sheet.flags["record_sealed"] = true
			EventBus.toast.emit("Fourteen clean days. The record is sealed. Background checks come back boring now.")
			EventBus.path_updated.emit()
	# Night school pays off, eventually.
	if sheet.flags.has("ged_done_day") and GameClock.day >= int(sheet.flags.ged_done_day):
		sheet.flags.erase("ged_done_day")
		sheet.flags["ged"] = true
		sheet.add_skill_xp("education", 60.0)
		EventBus.toast.emit("GED: passed. The certificate is flimsy. The doors it opens aren't.")
		EventBus.path_updated.emit()
	# Pregnancy and the baby gauntlet.
	if sheet.flags.has("pregnant_due_day") and GameClock.day >= int(sheet.flags.pregnant_due_day):
		sheet.flags.erase("pregnant_due_day")
		var kid_name: String = Coherence.FIRST_NAMES[_randi_index(Coherence.FIRST_NAMES.size())]
		sheet.children.append({"name": kid_name, "born_day": GameClock.day, "traits": []})
		EventBus.toast.emit("%s arrives at 4 AM, furious about everything. Congratulations." % kid_name)
	for kid in sheet.children:
		var age_days := GameClock.day - int(kid.born_day)
		if age_days <= 10: # night feeds: the gauntlet
			sheet.needs.change("energy", -15.0)
			var daycare := mini(1000, sheet.cash_cents)
			if daycare > 0:
				sheet.add_cash(-daycare)
		elif age_days == 25 and kid.traits.is_empty(): # 5 years old: who are they becoming?
			var traits: Array = []
			traits.append("sunny" if sheet.mood() >= 60.0 else "wary")
			if CrimeSystem.wanted_stars() > 0:
				traits.append("trouble_runs_in_the_family")
			kid.traits = traits
			EventBus.toast.emit("%s is five now. They're turning out... %s. You did that." % [
					kid.name, " and ".join(traits)])


## NPC aging + elder turnover; the town's population turns over across a
## long game. Called daily by EconomySystem.
static func age_npcs() -> void:
	for npc in WorldState.npcs.values():
		if not npc.alive:
			continue
		npc.age_years += 1.0 / DAYS_PER_YEAR
		if npc.age_years >= ELDER_AGE and _randf() < 0.006 + (npc.age_years - ELDER_AGE) * 0.002:
			Confrontation.kill_npc(npc, "old age")


# ------------------------------------------------------------------ heirs

## Children old enough to take over the lease and the grudges.
static func heir_candidates(sheet: CharacterSheet) -> Array:
	var out: Array = []
	for kid in sheet.children:
		if (GameClock.day - int(kid.born_day)) / DAYS_PER_YEAR >= 16.0:
			out.append(kid)
	return out


static func obituary(sheet: CharacterSheet, cause: String) -> String:
	var job := sheet.job()
	var warrants := 0
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			warrants += 1
	var lines := "%s, %d, of Rust Harbor — %s. %s %s Survived by %s." % [
		sheet.char_name, int(sheet.age_years), cause,
		("Worked as a %s." % job.display_name.to_lower()) if job else "Between opportunities.",
		("Wanted on %d charge%s at time of death." % [warrants, "" if warrants == 1 else "s"]) if warrants > 0 else "No outstanding warrants, for once.",
		("%d child%s" % [sheet.children.size(), "" if sheet.children.size() == 1 else "ren"]) if not sheet.children.is_empty() else "nobody in particular"]
	return lines


static func _randf() -> float:
	var rng := RandomNumberGenerator.new()
	if WorldState.body_rng_state == 0:
		WorldState.reset_body_rng()
	rng.seed = WorldState.body_rng_seed
	rng.state = WorldState.body_rng_state
	var value := rng.randf()
	WorldState.body_rng_state = rng.state
	return value


static func _randi_index(size: int) -> int:
	if size <= 0:
		return 0
	var rng := RandomNumberGenerator.new()
	if WorldState.body_rng_state == 0:
		WorldState.reset_body_rng()
	rng.seed = WorldState.body_rng_seed
	rng.state = WorldState.body_rng_state
	var value := rng.randi() % size
	WorldState.body_rng_state = rng.state
	return value
