class_name CrimeSystem
extends Node
## Crime, witnesses, warrants, cops, and jail v1. Plain Node in Main.tscn;
## all the law lives in static functions so headless tests can run trials.
##
## Pipeline: commit -> co-located witnesses see (id_confidence scaled by
## traits) -> each decides to report (civic duty vs friendship vs fear) ->
## reports become evidence -> warrant at 60 -> wanted stars -> a cop who
## shares your location starts an arrest confrontation. Non-reporters still
## gossip, and gossip that reaches a cop becomes half-confidence evidence —
## "nobody reported it" is not "nobody knows."

const REPORT_EVIDENCE_PER_CONFIDENCE := 50.0
const ANONYMOUS_BASELINE_EVIDENCE := 10.0
const GOSSIP_EVIDENCE_FACTOR := 25.0
const BAIL_CENTS_PER_DAY := 5000
const MAX_STARS := 5
const COP_CHECK_MINUTES := 5
const ARREST_COOLDOWN_MINUTES := 90
const EXTERIOR_WITNESS_RADIUS := 320.0
const SHOPLIFT_BASE_CATCH_CHANCE := 0.20
const SHOPLIFT_STEALTH_REDUCTION := 0.025
const SHOPLIFT_EMPTY_STORE_FACTOR := 0.35
const SHOPLIFT_BYSTANDER_PRESSURE := 0.15
const SHOPLIFT_CLERK_PRESSURE := 0.75
const SHOPLIFT_COP_PRESSURE := 1.50
const JAIL_EVENTS := [
	{
		"kind": "yard",
		"label": "yard weights",
		"text": "You spend yard time under rusted iron and worse advice.",
		"skill": "fitness",
		"skill_xp": 1.5,
		"cash_cents": 0,
		"need_deltas": {"energy": -4.0, "fun": 2.0},
	},
	{
		"kind": "library",
		"label": "library shift",
		"text": "You hide in the library stacks and leave with a sharper edge.",
		"skill": "education",
		"skill_xp": 1.0,
		"cash_cents": 0,
		"need_deltas": {"fun": 3.0},
	},
	{
		"kind": "kitchen",
		"label": "kitchen duty",
		"text": "Kitchen duty pays badly, but the coffee is hot and accounted for.",
		"skill": "cooking",
		"skill_xp": 1.0,
		"cash_cents": 200,
		"need_deltas": {"hunger": 5.0, "hygiene": -3.0},
	},
]
const JAIL_RELATIONSHIP_LOSS_PER_DAY := 3.0
const JAIL_RELATIONSHIP_LOSS_CAP := 25.0

var _arrest_cooldown_until := 0


func _ready() -> void:
	EventBus.minute_passed.connect(_on_minute_passed)
	EventBus.day_passed.connect(_on_day_passed)


# ------------------------------------------------------------ committing

## The player commits a crime. target = the wronged NPC (may be null);
## world_pos limits exterior witnesses to line-of-sight-ish range.
static func commit(crime_id: String, location_id: String, target: NPCRecord = null,
		world_pos := Vector2.INF) -> CrimeCase:
	var def := ContentDB.get_crime(crime_id)
	var sheet: CharacterSheet = WorldState.player_sheet
	var case := CrimeCase.new()
	case.id = "case_%04d" % WorldState.next_case_serial()
	case.crime_id = crime_id
	case.day = GameClock.day
	case.location_id = location_id
	case.evidence = ANONYMOUS_BASELINE_EVIDENCE

	var caught_red_handed := false
	for npc in witnesses_at(location_id, world_pos, target):
		case.witness_ids.append(npc.id)
		var conf := id_confidence(npc, sheet)
		npc.add_memory("crime", "player", def.witness_text, -0.6, def.gossip_salience)
		npc.memories.back()["case_id"] = case.id
		npc.change_rel("player", -def.severity * 2.0)
		EventBus.crime_witnessed.emit(npc.id, case.id)
		if npc.is_cop():
			caught_red_handed = true
		elif decides_to_report(npc, target == npc):
			case.evidence += conf * REPORT_EVIDENCE_PER_CONFIDENCE
			case.suspect_id = "player"
			if case.status == CrimeCase.UNREPORTED:
				case.status = CrimeCase.OPEN

	if target != null and target.alive:
		target.change_rel("player", -30.0)
		if not target.id in case.witness_ids:
			target.add_memory("crime", "player", def.witness_text, -0.9, def.gossip_salience + 1.0)
			target.memories.back()["case_id"] = case.id
			if decides_to_report(target, true):
				case.evidence += id_confidence(target, sheet) * REPORT_EVIDENCE_PER_CONFIDENCE
				case.suspect_id = "player"
				if case.status == CrimeCase.UNREPORTED:
					case.status = CrimeCase.OPEN

	if caught_red_handed:
		case.evidence = 100.0
		case.suspect_id = "player"

	case.evidence = clampf(case.evidence, 0.0, 100.0)
	if case.evidence >= CrimeCase.WARRANT_EVIDENCE and case.suspect_id == "player":
		case.status = CrimeCase.WARRANT
		sheet.infamy = clampf(sheet.infamy + def.severity, 0.0, 100.0)
		sheet.flags["last_warrant_day"] = GameClock.day
		EventBus.warrant_issued.emit(case.id)

	# Witnessed crime feeds town fear; the town responds like a town would.
	if not case.witness_ids.is_empty():
		WorldState.town_fear = minf(WorldState.town_fear + def.severity * 0.8, 100.0)

	WorldState.crime_cases[case.id] = case
	EventBus.crime_committed.emit(case.id)
	EventBus.wanted_changed.emit(wanted_stars())
	return case


## Everyone awake and alive who shares the scene (or is close, outside).
## At fear 40+ the streets empty out — the careful killer's perverse
## advantage, on purpose.
static func witnesses_at(location_id: String, world_pos := Vector2.INF,
		exclude: NPCRecord = null) -> Array:
	var out: Array = []
	var now := GameClock.total_minutes
	for npc in WorldState.npcs.values():
		if npc == exclude or not npc.alive or npc.current_activity == "sleeping":
			continue
		if npc.current_location_id != location_id:
			continue
		if location_id == "exterior" and world_pos != Vector2.INF \
				and npc.abstract_position(now).distance_to(world_pos) > EXTERIOR_WITNESS_RADIUS:
			continue
		if WorldState.town_fear >= 40.0 and _randf() < 0.3:
			continue # fewer people out; fewer eyes
		out.append(npc)
	return out


## How surely this witness could pick you out of a lineup, 0-1.
static func id_confidence(witness: NPCRecord, sheet: CharacterSheet) -> float:
	var conf := 0.8
	if absf(witness.rel("player")) > 20.0:
		conf += 0.15 # they KNOW you
	if sheet.has_tag("forgettable_face"):
		conf *= 0.5
	var outfit := ContentDB.get_item(str(sheet.flags.get("outfit", "")))
	if outfit and "disguise" in outfit.tags:
		conf *= 0.3 # the mask works; wearing one on the street is its own problem
	if TownLife.holiday_today() == "ALL HALLOWS":
		conf *= 0.5 # masks are normal for one night — crime spree night
	conf += sheet.fame * 0.002 # fame kills anonymity ("wait, aren't you—?")
	return clampf(conf, 0.0, 1.0)


## Civic duty, minus friendship, minus fear (yours specifically, or the
## general kind your infamy radiates), plus being the victim.
static func decides_to_report(witness: NPCRecord, is_victim: bool) -> bool:
	var score := float(witness.personality.get("civic_duty", 50))
	if witness.rel("player") >= 30.0:
		score -= 50.0
	if int(witness.flags.get("scared_of_player_until_day", -1)) >= GameClock.day:
		score -= 30.0
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet != null:
		score -= sheet.infamy * 0.3 # infamy terrifies witnesses...
	if is_victim:
		score += 40.0
	return score > 50.0


static func wanted_stars() -> int:
	var stars := 0
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			stars += 1
	return mini(stars, MAX_STARS)


static func roll_chance(chance: float) -> bool:
	return random_float() < clampf(chance, 0.0, 1.0)


static func random_float() -> float:
	return _randf()


static func random_int(min_value: int, max_value: int) -> int:
	var rng := _crime_rng()
	var value := rng.randi_range(min_value, max_value)
	_store_crime_rng(rng)
	return value


static func shoplift_catch_chance(sheet: CharacterSheet, location_id: String,
		world_pos := Vector2.INF) -> float:
	var base := clampf(SHOPLIFT_BASE_CATCH_CHANCE
			- SHOPLIFT_STEALTH_REDUCTION * sheet.skill_level("stealth"), 0.05, 1.0)
	var witnesses := witnesses_at(location_id, world_pos)
	if witnesses.is_empty():
		return clampf(base * SHOPLIFT_EMPTY_STORE_FACTOR, 0.02, 0.95)
	var pressure := 1.0
	for npc in witnesses:
		if npc.is_cop():
			pressure += SHOPLIFT_COP_PRESSURE
		elif npc.archetype_id == "store_clerk":
			pressure += SHOPLIFT_CLERK_PRESSURE
		else:
			pressure += SHOPLIFT_BYSTANDER_PRESSURE
	return clampf(base * pressure, 0.02, 0.95)


static func shoplift_attention_text(location_id: String, world_pos := Vector2.INF) -> String:
	var witnesses := witnesses_at(location_id, world_pos)
	if witnesses.is_empty():
		return "no one is watching closely"
	var cops := 0
	var clerks := 0
	for npc in witnesses:
		if npc.is_cop():
			cops += 1
		elif npc.archetype_id == "store_clerk":
			clerks += 1
	if cops > 0:
		return "%d cop%s in sight" % [cops, "" if cops == 1 else "s"]
	if clerks > 0:
		return "%d clerk%s watching" % [clerks, "" if clerks == 1 else "s"]
	return "%d shopper%s nearby" % [witnesses.size(), "" if witnesses.size() == 1 else "s"]


# ------------------------------------------------------------ the law's day

func _on_day_passed(_day: int) -> void:
	_decay_evidence()
	_process_cop_gossip()
	_bodies_and_detectives()


## Bodies surface; detectives canvass. Murder cases never expire — they
## only march toward you, faster if your name is already in the paper.
static func _bodies_and_detectives() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	for case in WorldState.crime_cases.values():
		if case.crime_id != "murder":
			continue
		if case.status == CrimeCase.UNREPORTED:
			if _randf() < 0.25: # discovery roll: traffic, smell, a dog
				case.status = CrimeCase.OPEN
				case.suspect_id = "player"
				case.evidence = clampf(case.evidence + 20.0, 0.0, 100.0)
				WorldState.town_fear = minf(WorldState.town_fear + 4.0, 100.0)
				WorldState.add_news("BODY DISCOVERED. The Gazette has run out of synonyms for 'grim'.")
		elif case.status == CrimeCase.OPEN:
			var canvass := 3.0 + (sheet.infamy * 0.05 if sheet else 0.0)
			case.evidence = clampf(case.evidence + canvass, 0.0, 100.0)
			if case.evidence >= CrimeCase.WARRANT_EVIDENCE and case.suspect_id == "player":
				case.status = CrimeCase.WARRANT
				if sheet:
					sheet.infamy = clampf(sheet.infamy + 10.0, 0.0, 100.0)
					sheet.flags["last_warrant_day"] = GameClock.day
				EventBus.warrant_issued.emit(case.id)
				EventBus.wanted_changed.emit(wanted_stars())


static func _decay_evidence() -> void:
	for case in WorldState.crime_cases.values():
		if case.status not in [CrimeCase.UNREPORTED, CrimeCase.OPEN]:
			continue
		var def: CrimeDef = case.def()
		if def == null or def.evidence_decay_per_day <= 0.0:
			continue
		case.evidence = maxf(case.evidence - def.evidence_decay_per_day, 0.0)
		if case.evidence <= 0.0:
			case.status = CrimeCase.COLD


## Gossip reaching a cop becomes half-confidence evidence.
static func _process_cop_gossip() -> void:
	for npc in WorldState.npcs.values():
		if not npc.alive or not npc.is_cop():
			continue
		for m in npc.memories:
			if m.get("kind", "") != "crime" or m.get("processed_by_law", false):
				continue
			m["processed_by_law"] = true
			var case: CrimeCase = WorldState.crime_cases.get(str(m.get("case_id", "")))
			if case == null or case.status in [CrimeCase.CLOSED, CrimeCase.WARRANT]:
				continue
			case.evidence = clampf(case.evidence + GOSSIP_EVIDENCE_FACTOR, 0.0, 100.0)
			case.suspect_id = "player"
			if case.status == CrimeCase.UNREPORTED:
				case.status = CrimeCase.OPEN
			if case.evidence >= CrimeCase.WARRANT_EVIDENCE:
				case.status = CrimeCase.WARRANT
				EventBus.warrant_issued.emit(case.id)
				EventBus.wanted_changed.emit(wanted_stars())


# ------------------------------------------------------------ cops on patrol

func _on_minute_passed(total: int) -> void:
	if total % COP_CHECK_MINUTES != 0 or total < _arrest_cooldown_until:
		return
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null or not sheet.alive or wanted_stars() == 0:
		return
	if sheet.flags.get("jailed", false):
		return # you're already exactly where they want you
	var cop := _cop_who_spots_player()
	if cop == null:
		return
	var cooldown := ARREST_COOLDOWN_MINUTES
	if sheet.flags.get("police_budget_low", false):
		cooldown *= 3 # the mayor gutted patrols. The mayor is you.
	_arrest_cooldown_until = total + cooldown
	EventBus.confrontation_started.emit({
		"kind": "arrest", "npc_id": cop.id,
		"text": "Officer %s squares up: \"Stop right there. We've been looking for you.\"" % cop.display_name,
	})


func _cop_who_spots_player() -> NPCRecord:
	var player_loc: String = WorldState.player_location_id
	var ppos := Vector2.INF
	if player_loc == "exterior" and SimEngine.player_node != null:
		ppos = SimEngine.player_node.global_position
	var now := GameClock.total_minutes
	for npc in WorldState.npcs.values():
		if not npc.alive or not npc.is_cop() or npc.current_activity == "sleeping":
			continue
		if npc.current_location_id != player_loc:
			continue
		if player_loc == "exterior" and ppos != Vector2.INF \
				and npc.abstract_position(now).distance_to(ppos) > 380.0:
			continue
		if int(npc.flags.get("bribed_until_day", -1)) >= GameClock.day:
			continue
		return npc
	return null


# ------------------------------------------------------------ jail v1

static func total_sentence_days() -> int:
	var days := 0
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			days += case.def().sentence_days_min if case.def() else 1
	return clampi(days, 1, 90)


static func bail_cents() -> int:
	return total_sentence_days() * BAIL_CENTS_PER_DAY


static func all_warrants_bailable() -> bool:
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant() and case.def() and not case.def().bailable:
			return false
	return true


## Pay your way out: warrants close, no time served. Mel would be proud.
static func pay_bail() -> bool:
	var sheet: CharacterSheet = WorldState.player_sheet
	var cost := bail_cents()
	if not all_warrants_bailable() or sheet.cash_cents < cost:
		return false
	sheet.add_cash(-cost)
	_close_warrants()
	EventBus.toast.emit("Bail posted: $%.2f. The desk sergeant counts it twice." % (cost / 100.0))
	EventBus.wanted_changed.emit(0)
	return true


## Serve the time. Days pass for the whole town — rent included.
static func serve_sentence() -> int:
	var sheet: CharacterSheet = WorldState.player_sheet
	var days := total_sentence_days()
	var events: Array = []
	EventBus.arrest_made.emit(days)
	sheet.flags["jailed"] = true
	sheet.flags["last_jail_events"] = []
	for _d in days:
		# Jail feeds you. Not well, but on schedule.
		sheet.flags["calories_today"] = maxi(int(sheet.flags.get("calories_today", 0)), 1700)
		GameClock.skip_minutes(GameClock.MINUTES_PER_DAY)
		sheet.needs.change("hunger", 60.0)
		sheet.needs.change("energy", 50.0)
		sheet.needs.change("hygiene", 20.0)
		sheet.needs.change("fun", -5.0)
		sheet.add_skill_xp("fitness", 0.5) # base prison-physique pipeline
		events.append(_apply_jail_day_event(sheet, events.size() + 1))
	sheet.flags["last_jail_events"] = events
	sheet.flags["jail_days_served_total"] = int(sheet.flags.get("jail_days_served_total", 0)) + days
	var contacts := _apply_jail_inmate_contacts(sheet, days)
	sheet.flags["last_jail_contacts"] = contacts
	var consequences := _apply_jail_absence_consequences(sheet, days)
	sheet.flags["last_jail_consequences"] = consequences
	sheet.flags.erase("jailed")
	_close_warrants()
	var event_text := jail_event_summary(events)
	var detail := " Jail days: %s." % event_text if event_text != "" else ""
	var contact_text := jail_contact_summary(contacts)
	if contact_text != "":
		detail += " Inside: %s." % contact_text
	var consequence_text := jail_consequence_summary(consequences)
	if consequence_text != "":
		detail += " Outside: %s." % consequence_text
	EventBus.toast.emit("%d day%s gone.%s The gate opens onto the same town, minus some rent money." % [
			days, "" if days == 1 else "s", detail])
	EventBus.wanted_changed.emit(0)
	return days


static func _apply_jail_day_event(sheet: CharacterSheet, day_number: int) -> Dictionary:
	var event_def: Dictionary = JAIL_EVENTS[random_int(0, JAIL_EVENTS.size() - 1)]
	var skill := str(event_def.get("skill", ""))
	var skill_xp := float(event_def.get("skill_xp", 0.0))
	if skill != "" and skill_xp > 0.0:
		sheet.add_skill_xp(skill, skill_xp)
	var cash_cents := int(event_def.get("cash_cents", 0))
	if cash_cents != 0:
		sheet.add_cash(cash_cents)
	var need_deltas: Dictionary = event_def.get("need_deltas", {})
	for need_id in need_deltas:
		sheet.needs.change(str(need_id), float(need_deltas[need_id]))
	return {
		"day": day_number,
		"kind": str(event_def.get("kind", "")),
		"label": str(event_def.get("label", "")),
		"text": str(event_def.get("text", "")),
		"skill": skill,
		"skill_xp": skill_xp,
		"cash_cents": cash_cents,
	}


static func jail_event_summary(events: Array) -> String:
	if events.is_empty():
		return ""
	var labels: Array = []
	for event in events:
		if labels.size() >= 3:
			break
		labels.append(str(event.get("label", "a long day")))
	var summary := "; ".join(labels)
	var remaining := events.size() - labels.size()
	if remaining > 0:
		summary += "; +%d more" % remaining
	return summary


static func jail_consequence_summary(consequences: Dictionary) -> String:
	var parts: Array = []
	var strained := int(consequences.get("relationships_strained", 0))
	if strained > 0:
		parts.append("%d relationship%s strained" % [strained, "" if strained == 1 else "s"])
	var child_days := int(consequences.get("child_services_days", 0))
	if child_days > 0:
		parts.append("Child Services file +%d" % child_days)
	return "; ".join(parts)


static func jail_contact_summary(contacts: Array) -> String:
	if contacts.is_empty():
		return ""
	var labels: Array = []
	for contact in contacts:
		labels.append(str(contact.get("name", "somebody")))
	return "met %s" % ", ".join(labels)


static func _apply_jail_inmate_contacts(sheet: CharacterSheet, days: int) -> Array:
	var candidates: Array = []
	for npc in WorldState.npcs.values():
		if not npc.alive or npc.is_cop():
			continue
		if npc.flags.get("dating_player", false) or npc.flags.get("married_to_player", false):
			continue
		var arch: ArchetypeDef = npc.archetype()
		if arch == null or not ("criminal_leaning" in arch.tags):
			continue
		candidates.append(npc)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: NPCRecord, b: NPCRecord) -> bool:
		return a.id < b.id)
	var contact: NPCRecord = candidates[random_int(0, candidates.size() - 1)]
	var rel_gain := minf(5.0 + days, 15.0)
	contact.change_rel("player", rel_gain)
	contact.flags["met_player_in_jail"] = true
	contact.add_memory("jail_contact", "player",
			"did time with you and traded names before release", 0.35, 7.5)
	_append_unique_flag_id(sheet, "jail_contact_ids", contact.id)
	_append_unique_flag_id(sheet, "underworld_contact_ids", contact.id)
	return [{
		"id": contact.id,
		"name": contact.display_name,
		"relationship_gain": rel_gain,
	}]


static func _apply_jail_absence_consequences(sheet: CharacterSheet, days: int) -> Dictionary:
	var strained_names: Array = []
	var rel_loss := minf(days * JAIL_RELATIONSHIP_LOSS_PER_DAY, JAIL_RELATIONSHIP_LOSS_CAP)
	for npc in WorldState.npcs.values():
		if not npc.alive:
			continue
		if not npc.flags.get("dating_player", false) and not npc.flags.get("married_to_player", false):
			continue
		npc.change_rel("player", -rel_loss)
		npc.add_memory("jail_absence", "player",
				"served time while you held life together outside", -0.45, 6.5)
		strained_names.append(npc.display_name)
	var child_days := days if not sheet.children.is_empty() else 0
	if child_days > 0:
		sheet.flags["child_services_file"] = int(sheet.flags.get("child_services_file", 0)) + child_days
		if int(sheet.flags["child_services_file"]) >= 3:
			sheet.flags["child_services_warning"] = true
	return {
		"relationships_strained": strained_names.size(),
		"strained_names": strained_names,
		"relationship_loss": rel_loss if not strained_names.is_empty() else 0.0,
		"child_services_days": child_days,
		"child_services_file": int(sheet.flags.get("child_services_file", 0)),
		"child_services_warning": sheet.flags.get("child_services_warning", false),
	}


static func _append_unique_flag_id(sheet: CharacterSheet, flag_id: String, value: String) -> void:
	var values: Array = sheet.flags.get(flag_id, []).duplicate()
	if value not in values:
		values.append(value)
	sheet.flags[flag_id] = values


static func _close_warrants() -> void:
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			case.status = CrimeCase.CLOSED


static func _randf() -> float:
	var rng := _crime_rng()
	var value := rng.randf()
	_store_crime_rng(rng)
	return value


static func _crime_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if WorldState.crime_rng_state == 0:
		WorldState.reset_crime_rng()
	rng.seed = WorldState.crime_rng_seed
	rng.state = WorldState.crime_rng_state
	return rng


static func _store_crime_rng(rng: RandomNumberGenerator) -> void:
	WorldState.crime_rng_state = rng.state
