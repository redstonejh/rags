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
		EventBus.warrant_issued.emit(case.id)

	WorldState.crime_cases[case.id] = case
	EventBus.crime_committed.emit(case.id)
	EventBus.wanted_changed.emit(wanted_stars())
	return case


## Everyone awake and alive who shares the scene (or is close, outside).
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
	return clampf(conf, 0.0, 1.0)


## Civic duty, minus friendship, minus fear, plus being the victim.
static func decides_to_report(witness: NPCRecord, is_victim: bool) -> bool:
	var score := float(witness.personality.get("civic_duty", 50))
	if witness.rel("player") >= 30.0:
		score -= 50.0
	if int(witness.flags.get("scared_of_player_until_day", -1)) >= GameClock.day:
		score -= 30.0
	if is_victim:
		score += 40.0
	return score > 50.0


static func wanted_stars() -> int:
	var stars := 0
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			stars += 1
	return mini(stars, MAX_STARS)


# ------------------------------------------------------------ the law's day

func _on_day_passed(_day: int) -> void:
	_decay_evidence()
	_process_cop_gossip()


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
	var cop := _cop_who_spots_player()
	if cop == null:
		return
	_arrest_cooldown_until = total + ARREST_COOLDOWN_MINUTES
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
	EventBus.arrest_made.emit(days)
	sheet.flags["jailed"] = true
	for _d in days:
		# Jail feeds you. Not well, but on schedule.
		sheet.flags["calories_today"] = maxi(int(sheet.flags.get("calories_today", 0)), 1700)
		GameClock.skip_minutes(GameClock.MINUTES_PER_DAY)
		sheet.needs.change("hunger", 60.0)
		sheet.needs.change("energy", 50.0)
		sheet.needs.change("hygiene", 20.0)
		sheet.needs.change("fun", -5.0)
		sheet.add_skill_xp("fitness", 1.0) # yard weights: the prison-physique pipeline
	sheet.flags.erase("jailed")
	_close_warrants()
	EventBus.toast.emit("%d day%s gone. The gate opens onto the same town, minus some rent money." % [
			days, "" if days == 1 else "s"])
	EventBus.wanted_changed.emit(0)
	return days


static func _close_warrants() -> void:
	for case in WorldState.crime_cases.values():
		if case.is_active_warrant():
			case.status = CrimeCase.CLOSED
