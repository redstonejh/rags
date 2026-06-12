extends Node
## M5 smoke test — run headless:
##   godot --headless res://scenes/dev/M5SmokeTest.tscn
## Exercises crime + consequences: the witness pipeline (civic duty vs
## friendship vs fear vs victimhood), warrants and wanted stars, evidence
## decay, gossip becoming evidence when it reaches a cop, the universal
## confrontation (carjack fight -> mercy/rob/kill), arrest/bail/bribe/jail,
## pickpocketing, the fence, and the save round trip of every case.

var failures: int = 0
var _died: Array = []
var _save_guard := SaveSlotGuard.new()


func _ready() -> void:
	_save_guard.backup()
	var town: Node2D = load("res://scenes/world/Town.tscn").instantiate()
	add_child(town)
	add_child(CrimeSystem.new())
	EventBus.npc_died.connect(func(id: String, cause: String) -> void: _died.append([id, cause]))

	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_world(sheet)

	_test_catalog()
	_test_witness_pipeline()
	_test_forgettable_face()
	_test_cop_red_handed()
	_test_evidence_decay()
	_test_gossip_to_cop()
	_test_carjack_fight()
	_test_crime_rng_save_roundtrip()
	_test_crime_rng_public_rolls_roundtrip()
	_test_shoplift_sightlines()
	_test_register_robbery_is_never_quiet()
	_test_register_silent_alarm_response()
	_test_arrest_paths()
	_test_pickpocket()
	_test_fence()
	_test_dead_npcs()
	_test_save_roundtrip()
	_test_parked_car_rng_save_roundtrip()
	SaveManager.set_in_game(false)
	_save_guard.restore()
	print("M5 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _mk_npc(id: String, loc: String, civic: int, str_val := 8, bravery := 50,
		archetype := "barfly") -> NPCRecord:
	var n := NPCRecord.new()
	n.id = id
	n.display_name = "Probe %s" % id
	n.archetype_id = archetype
	n.appearance_tags = ["plain"]
	for s in CharacterSheet.STAT_IDS:
		n.stats[s] = 8
	n.stats["STR"] = str_val
	n.personality = {"bravery": bravery, "greed": 50, "civic_duty": civic,
			"kindness": 50, "chattiness": 50, "jealousy": 10}
	n.home_id = "loc_bricks"
	n.current_location_id = loc
	n.current_activity = "idle"
	n.money_cents = 20000
	WorldState.npcs[n.id] = n
	return n


func _fresh_sheet() -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	return sheet


func _test_catalog() -> void:
	print("[Crime catalog]")
	_check(ContentDB.crimes.size() >= 8, "8+ crimes loaded (%d)" % ContentDB.crimes.size())
	var murder := ContentDB.get_crime("murder")
	_check(murder != null and murder.evidence_decay_per_day == 0.0, "murder evidence never decays")


func _test_witness_pipeline() -> void:
	print("[Witness pipeline: see -> identify -> decide -> report]")
	_fresh_sheet()
	# One upstanding citizen: reports, but one witness isn't a warrant.
	_mk_npc("w_snitch", "loc_scene_a", 90)
	var case_a := CrimeSystem.commit("pickpocket", "loc_scene_a")
	_check(case_a.status == CrimeCase.OPEN, "one report opens the case")
	_check(case_a.evidence >= 40.0 and case_a.evidence < 60.0,
			"one confident witness ≈ 50 evidence (%.0f)" % case_a.evidence)
	# A second snitch pushes it over the warrant line.
	_mk_npc("w_snitch2", "loc_scene_a", 90)
	var case_b := CrimeSystem.commit("pickpocket", "loc_scene_a")
	_check(case_b.status == CrimeCase.WARRANT, "two reports = warrant (%.0f evidence)" % case_b.evidence)
	_check(CrimeSystem.wanted_stars() >= 1, "warrant = wanted star")
	# Friends don't snitch — but they remember.
	var friend := _mk_npc("w_friend", "loc_scene_b", 90)
	friend.relationships["player"] = 60.0
	var case_c := CrimeSystem.commit("pickpocket", "loc_scene_b")
	_check(case_c.status == CrimeCase.UNREPORTED, "a friend looks away (no report)")
	_check(friend.memories.any(func(m: Dictionary) -> bool: return m.get("kind", "") == "crime"),
			"...but the friend still KNOWS")
	# Victims report even with thin civic spirit.
	var victim := _mk_npc("w_victim", "loc_scene_c", 30)
	var case_d := CrimeSystem.commit("pickpocket", "loc_scene_c", victim)
	_check(case_d.status != CrimeCase.UNREPORTED, "the victim reports (civic 30 + victim 40)")
	CrimeSystem._close_warrants()


func _test_forgettable_face() -> void:
	print("[Forgettable Face: witnesses halve]")
	var sheet := _fresh_sheet()
	sheet.trait_ids = ["forgettable_face"]
	_mk_npc("w_blur", "loc_scene_d", 90)
	var case := CrimeSystem.commit("pickpocket", "loc_scene_d")
	_check(case.evidence < 40.0, "forgettable face halves ID confidence (%.0f evidence)" % case.evidence)
	_fresh_sheet()


func _test_cop_red_handed() -> void:
	print("[Cops: crime in front of one]")
	_fresh_sheet()
	_mk_npc("w_cop", "loc_scene_e", 100, 10, 80, "cop")
	var case := CrimeSystem.commit("shoplift", "loc_scene_e")
	_check(case.evidence >= 100.0, "caught red-handed = evidence 100")
	_check(case.status == CrimeCase.WARRANT, "instant warrant")
	CrimeSystem._close_warrants()
	EventBus.wanted_changed.emit(CrimeSystem.wanted_stars())


func _test_evidence_decay() -> void:
	print("[Evidence decays; cases go cold]")
	_fresh_sheet()
	var case := CrimeSystem.commit("pickpocket", "loc_nowhere") # no witnesses
	_check(case.status == CrimeCase.UNREPORTED and case.evidence <= 20.0,
			"unwitnessed crime stays anonymous (%.0f)" % case.evidence)
	for _d in 3:
		CrimeSystem._decay_evidence()
	_check(case.status == CrimeCase.COLD, "anonymous case goes cold in days")


func _test_gossip_to_cop() -> void:
	print("[Gossip reaching a cop becomes evidence]")
	_fresh_sheet()
	var teller := _mk_npc("w_teller", "loc_scene_f", 40) # didn't report (40 < 50)...
	var case := CrimeSystem.commit("car_theft", "loc_scene_f")
	_check(case.status == CrimeCase.UNREPORTED, "low-civic witness kept quiet")
	var cop: NPCRecord = WorldState.npcs["w_cop"]
	var shared := GossipSystem.share(teller, cop)
	_check(shared, "the story reaches Officer w_cop at the diner")
	CrimeSystem._process_cop_gossip()
	_check(case.evidence > 10.0 and case.suspect_id == "player",
			"hearsay becomes half-confidence evidence (%.0f)" % case.evidence)
	_check(case.status == CrimeCase.OPEN, "the case is open now")


func _test_carjack_fight() -> void:
	print("[Confrontation: the carjack gamble]")
	var sheet := _fresh_sheet()
	sheet.base_stats["STR"] = 15
	var pushover := _mk_npc("w_push", "exterior", 50, 6, 10)
	var cases_before := WorldState.crime_cases.size()
	var result := Confrontation.resolve("carjack", "fight", sheet, pushover, 0.1)
	_check(result.success and str(result.follow_up.get("kind", "")) == "standoff_win",
			"winning the fight chains to the standoff")
	_check(WorldState.crime_cases.size() == cases_before + 1, "the swing itself is an assault case")
	# Rob them while they're down.
	var dirty_before := sheet.dirty_cents
	var robbery_events := {"money": 0}
	var robbery_money_signal := func(_cash_cents: int) -> void:
		robbery_events["money"] = int(robbery_events.money) + 1
	EventBus.money_changed.connect(robbery_money_signal)
	Confrontation.resolve("standoff_win", "rob", sheet, pushover)
	EventBus.money_changed.disconnect(robbery_money_signal)
	_check(sheet.dirty_cents > dirty_before, "robbery pays dirty")
	_check(int(robbery_events.money) > 0, "robbery dirty payout refreshes money UI")
	# Or end them: a murder case, a permanent absence.
	var victim := _mk_npc("w_dead", "exterior", 50, 6, 10)
	Confrontation.resolve("standoff_win", "kill", sheet, victim)
	_check(not victim.alive, "killed NPCs stay dead")
	_check(_died.size() == 1 and _died[0][0] == "w_dead", "npc_died emitted")
	var murder_exists := false
	for c in WorldState.crime_cases.values():
		if c.crime_id == "murder":
			murder_exists = true
	_check(murder_exists, "a murder case exists; it will never decay")
	# Losing a fight you started hurts.
	var weak := _fresh_sheet()
	var wall := _mk_npc("w_wall", "exterior", 50, 15, 90)
	var loss := Confrontation.resolve("carjack", "fight", weak, wall, 0.99)
	_check(not loss.success and weak.needs.get_value("energy") < 100.0,
			"losing your own fight costs you")
	CrimeSystem._close_warrants()


func _test_crime_rng_save_roundtrip() -> void:
	print("[Save round trip: crime RNG]")
	var sheet := _fresh_sheet()
	WorldState.crime_cases.clear()
	WorldState.gazette = []
	WorldState.town_fear = 0.0
	WorldState.world_seed = 555123
	WorldState.reset_crime_rng()
	var case := CrimeSystem.commit("murder", "loc_hidden")
	_check(case.status == CrimeCase.UNREPORTED, "silent murder exists before discovery roll")
	var before_state := WorldState.crime_rng_state
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success with crime RNG state")
	CrimeSystem._bodies_and_detectives()
	var expected := _crime_signature()
	_check(WorldState.crime_rng_state != before_state,
			"body discovery advances saved crime RNG state")
	WorldState.player_sheet = null
	WorldState.crime_cases.clear()
	WorldState.gazette = []
	WorldState.town_fear = 0.0
	WorldState.crime_rng_state = 0
	_check(SaveManager.load_game(), "load_game restores crime RNG state")
	CrimeSystem._bodies_and_detectives()
	_check(_crime_signature() == expected,
			"loaded crime RNG repeats the same body-discovery result")
	SaveManager.set_in_game(false)
	WorldState.player_sheet = sheet


func _test_crime_rng_public_rolls_roundtrip() -> void:
	print("[Save round trip: public crime rolls]")
	var sheet := _fresh_sheet()
	WorldState.world_seed = 612024
	WorldState.reset_crime_rng()
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success with public crime RNG state")
	var expected := [
		CrimeSystem.random_float(),
		CrimeSystem.roll_chance(0.20),
		CrimeSystem.random_int(20000, 60000),
		CrimeSystem.roll_chance(0.05),
		str(WorldState.crime_rng_state),
	]
	WorldState.crime_rng_state = 0
	_check(SaveManager.load_game(), "load_game restores public crime RNG state")
	var actual := [
		CrimeSystem.random_float(),
		CrimeSystem.roll_chance(0.20),
		CrimeSystem.random_int(20000, 60000),
		CrimeSystem.roll_chance(0.05),
		str(WorldState.crime_rng_state),
	]
	_check(actual == expected, "loaded public crime rolls repeat shop outcomes")
	SaveManager.set_in_game(false)
	WorldState.player_sheet = sheet


func _test_shoplift_sightlines() -> void:
	print("[Shoplifting: sightlines change risk]")
	var sheet := _fresh_sheet()
	WorldState.town_fear = 0.0
	var empty := CrimeSystem.shoplift_catch_chance(sheet, "loc_shop_empty")
	_mk_npc("shop_bystander", "loc_shop_busy", 50)
	var bystander := CrimeSystem.shoplift_catch_chance(sheet, "loc_shop_busy")
	_mk_npc("shop_clerk", "loc_shop_clerk", 90, 8, 40, "store_clerk")
	var clerk := CrimeSystem.shoplift_catch_chance(sheet, "loc_shop_clerk")
	_mk_npc("shop_cop", "loc_shop_cop", 100, 10, 80, "cop")
	var cop := CrimeSystem.shoplift_catch_chance(sheet, "loc_shop_cop")
	_check(empty < bystander and bystander < clerk and clerk < cop,
			"sightlines scale shoplift risk (%.0f%% < %.0f%% < %.0f%% < %.0f%%)" % [
				empty * 100.0, bystander * 100.0, clerk * 100.0, cop * 100.0])
	_check("clerk" in CrimeSystem.shoplift_attention_text("loc_shop_clerk"),
			"shoplift attention names the clerk")
	var no_witness_case := CrimeSystem.commit("shoplift", "loc_shop_empty")
	_check(no_witness_case.status == CrimeCase.UNREPORTED,
			"caught unwatched shoplifting stays anonymous")
	var clerk_case := CrimeSystem.commit("shoplift", "loc_shop_clerk")
	_check(clerk_case.status == CrimeCase.OPEN and clerk_case.evidence > no_witness_case.evidence,
			"clerk-witnessed shoplifting opens a stronger case")
	var cop_case := CrimeSystem.commit("shoplift", "loc_shop_cop")
	_check(cop_case.is_active_warrant(), "shoplifting in front of a cop is instant warrant")
	CrimeSystem._close_warrants()


func _test_register_robbery_is_never_quiet() -> void:
	print("[Register robbery: never quiet]")
	var sheet := _fresh_sheet()
	WorldState.crime_cases.clear()
	WorldState.gazette = []
	WorldState.town_fear = 0.0
	var case := CrimeSystem.commit_register_robbery("loc_empty_register")
	_check(case.crime_id == "armed_robbery", "register robbery records armed robbery")
	_check(case.is_active_warrant(), "register robbery creates a warrant without bystanders")
	_check(case.evidence >= CrimeCase.WARRANT_EVIDENCE,
			"register robbery forces warrant-grade evidence")
	_check(CrimeSystem.wanted_stars() == 1, "register robbery raises wanted stars")
	_check(sheet.infamy >= 6.0, "register robbery adds infamy")
	_check(not WorldState.gazette.is_empty()
			and "QUIKSTOP ROBBED" in str(WorldState.gazette.back().get("text", "")),
			"register robbery makes the Gazette")
	CrimeSystem._close_warrants()


func _test_register_silent_alarm_response() -> void:
	print("[Register robbery: silent alarm response]")
	var sheet := _fresh_sheet()
	WorldState.crime_cases.clear()
	WorldState.gazette = []
	WorldState.player_location_id = "loc_alarm_store"
	GameClock.total_minutes = 10 * 60
	_mk_npc("alarm_cop", "loc_alarm_store", 100, 10, 80, "cop")
	var payloads: Array = []
	var handler := func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true))
	EventBus.confrontation_started.connect(handler)
	CrimeSystem.commit_register_robbery("loc_alarm_store", Vector2.INF, 0.0)
	var alarm_minute := int(sheet.flags.get("silent_alarm_minute", -1))
	_check(alarm_minute == GameClock.total_minutes + CrimeSystem.REGISTER_SILENT_ALARM_MINUTES,
			"silent alarm schedules a three-minute response")
	EventBus.minute_passed.emit(alarm_minute - 1)
	_check(payloads.is_empty(), "silent alarm does not fire early")
	EventBus.minute_passed.emit(alarm_minute)
	_check(payloads.size() == 1 and str(payloads[0].get("kind", "")) == "arrest",
			"silent alarm opens an arrest confrontation")
	_check(not sheet.flags.has("silent_alarm_minute")
			and not sheet.flags.has("silent_alarm_location_id"),
			"silent alarm clears after response")
	EventBus.confrontation_started.disconnect(handler)
	CrimeSystem._close_warrants()

	var quiet_sheet := _fresh_sheet()
	WorldState.crime_cases.clear()
	CrimeSystem.commit_register_robbery("loc_alarm_store", Vector2.INF, 0.99)
	_check(not quiet_sheet.flags.has("silent_alarm_minute"),
			"high alarm roll skips silent alarm")
	CrimeSystem._close_warrants()


func _test_parked_car_rng_save_roundtrip() -> void:
	print("[Save round trip: parked car crime RNG]")
	var sheet := _fresh_sheet()
	WorldState.world_seed = 612025
	WorldState.reset_crime_rng()
	WorldState.crime_cases.clear()
	WorldState.npcs.clear()
	WorldState.town_fear = 0.0
	WorldState.player_location_id = "exterior"
	_mk_npc("car_b", "exterior", 60, 10, 50)
	_mk_npc("car_a", "exterior", 60, 10, 50)
	_mk_npc("car_sleep", "exterior", 60, 10, 50).current_activity = "sleeping"
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success before occupied carjack")
	var expected_occupied := _parked_car_occupied_signature()
	WorldState.npcs.clear()
	WorldState.crime_rng_state = 0
	_check(SaveManager.load_game(), "load_game restores occupied carjack RNG state")
	var actual_occupied := _parked_car_occupied_signature()
	_check(actual_occupied == expected_occupied,
			"loaded occupied carjack repeats occupant selection")

	sheet = _fresh_sheet()
	WorldState.world_seed = 612026
	WorldState.reset_crime_rng()
	WorldState.crime_cases.clear()
	WorldState.npcs.clear()
	sheet.dirty_cents = 0
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success before empty carjack")
	var expected_empty := _parked_car_empty_signature()
	WorldState.crime_cases.clear()
	WorldState.crime_rng_state = 0
	WorldState.player_sheet = null
	_check(SaveManager.load_game(), "load_game restores empty carjack RNG state")
	var actual_empty := _parked_car_empty_signature()
	_check(actual_empty == expected_empty,
			"loaded empty carjack repeats payout and car-theft case")
	SaveManager.set_in_game(false)
	WorldState.player_sheet = sheet


func _parked_car_occupied_signature() -> Dictionary:
	var car := ParkedCar.new()
	add_child(car)
	car.occupied_chance = 1.0
	var payload := {}
	var handler := func(data: Dictionary) -> void:
		payload = data.duplicate(true)
	EventBus.confrontation_started.connect(handler)
	car.interact(null)
	EventBus.confrontation_started.disconnect(handler)
	car.queue_free()
	return {
		"npc_id": str(payload.get("npc_id", "")),
		"crime_rng_state": str(WorldState.crime_rng_state),
	}


func _parked_car_empty_signature() -> Dictionary:
	var car := ParkedCar.new()
	add_child(car)
	car.occupied_chance = 0.0
	var dirty_before := WorldState.player_sheet.dirty_cents
	car.interact(null)
	var ids := WorldState.crime_cases.keys()
	ids.sort()
	var case: CrimeCase = WorldState.crime_cases.get(str(ids[0])) if not ids.is_empty() else null
	return {
		"dirty_gain": WorldState.player_sheet.dirty_cents - dirty_before,
		"case_count": WorldState.crime_cases.size(),
		"crime_id": case.crime_id if case != null else "",
		"status": case.status if case != null else "",
		"crime_rng_state": str(WorldState.crime_rng_state),
	}


func _crime_signature() -> String:
	var ids := WorldState.crime_cases.keys()
	ids.sort()
	var rows := []
	for id in ids:
		var case: CrimeCase = WorldState.crime_cases[id]
		rows.append(case.to_dict())
	return JSON.stringify({
		"cases": rows,
		"gazette": WorldState.gazette,
		"town_fear": WorldState.town_fear,
		"crime_rng_state": str(WorldState.crime_rng_state),
	})


func _test_arrest_paths() -> void:
	print("[Arrest: comply / bail / bribe]")
	# Comply: serve shoplift's 1-day minimum; clock moves, warrants clear.
	var sheet := _fresh_sheet()
	_mk_npc("w_law1", "loc_scene_g", 100, 10, 80, "cop")
	var partner := _mk_npc("w_partner", "loc_home", 50)
	partner.relationships["player"] = 80.0
	partner.flags["dating_player"] = true
	_mk_npc("w_cellmate", "loc_home", 40, 9, 45, "barfly")
	sheet.children = [{"name": "Dot", "born_day": GameClock.day - 1, "traits": []}]
	CrimeSystem.commit("shoplift", "loc_scene_g")
	var cop: NPCRecord = WorldState.npcs["w_law1"]
	var day_before := GameClock.day
	var result := Confrontation.resolve("arrest", "comply", sheet, cop)
	_check(result.success and GameClock.day == day_before + 1, "served 1 day for shoplifting")
	_check(CrimeSystem.wanted_stars() == 0, "warrants cleared by serving")
	_check(float(sheet.skills.get("fitness", 0.0)) > 0.0, "yard weights: fitness XP in jail")
	_check(str(result.get("text", "")).contains("Jail days:"),
			"arrest result summarizes jail days")
	_check(str(result.get("text", "")).contains("Inside:"),
			"arrest result summarizes inmate contact")
	_check(str(result.get("text", "")).contains("Outside:"),
			"arrest result summarizes outside consequences")
	var jail_events: Array = sheet.flags.get("last_jail_events", [])
	_check(jail_events.size() == 1, "serving records a daily jail event")
	if not jail_events.is_empty():
		var jail_event: Dictionary = jail_events[0]
		_check(str(jail_event.get("kind", "")) in _jail_event_kinds(),
				"jail event kind is data-backed (%s)" % jail_event.get("kind", ""))
		_check(str(jail_event.get("text", "")) != "",
				"jail event includes player-facing text")
	var jail_consequences: Dictionary = sheet.flags.get("last_jail_consequences", {})
	var jail_contacts: Array = sheet.flags.get("last_jail_contacts", [])
	_check(jail_contacts.size() == 1, "serving records an inmate contact")
	if not jail_contacts.is_empty():
		var contact_id := str(jail_contacts[0].get("id", ""))
		var contact: NPCRecord = WorldState.npcs.get(contact_id)
		_check(contact != null and contact.flags.get("met_player_in_jail", false),
				"inmate contact persists on the NPC record")
		_check(contact != null and contact.knows_memory("player",
				"did time with you and traded names before release"),
				"inmate contact remembers the jail introduction")
		_check(contact_id in sheet.flags.get("underworld_contact_ids", []),
				"inmate contact opens an underworld contact")
	_check(partner.rel("player") < 80.0, "jail strains outside relationships")
	_check(int(jail_consequences.get("relationships_strained", 0)) == 1,
			"serving records strained relationship count")
	_check(int(sheet.flags.get("child_services_file", 0)) == 1,
			"jail starts a Child Services file for parents")
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success with jail event history")
	WorldState.player_sheet = null
	_check(SaveManager.load_game(), "load_game restores jail event history")
	_check(_same_jail_events(WorldState.player_sheet.flags.get("last_jail_events", []), jail_events),
			"jail event history survives save/load")
	var loaded_partner: NPCRecord = WorldState.npcs.get("w_partner")
	_check(loaded_partner != null and loaded_partner.rel("player") < 80.0,
			"jail relationship strain survives save/load")
	_check(int(WorldState.player_sheet.flags.get("child_services_file", 0)) == 1,
			"Child Services file survives save/load")
	if not jail_contacts.is_empty():
		var loaded_contact_id := str(jail_contacts[0].get("id", ""))
		var loaded_contact: NPCRecord = WorldState.npcs.get(loaded_contact_id)
		_check(loaded_contact != null and loaded_contact.flags.get("met_player_in_jail", false),
				"inmate contact survives save/load")
		_check(loaded_contact_id in WorldState.player_sheet.flags.get("underworld_contact_ids", []),
				"underworld contact id survives save/load")
	SaveManager.set_in_game(false)
	sheet = WorldState.player_sheet
	cop = WorldState.npcs["w_law1"]
	# Bail: money makes it a paperwork problem.
	CrimeSystem.commit("shoplift", "loc_scene_g")
	sheet.cash_cents = 20000
	var bail := CrimeSystem.bail_cents()
	var ok := CrimeSystem.pay_bail()
	_check(ok and sheet.cash_cents == 20000 - bail, "bail posted ($%d)" % (bail / 100))
	_check(CrimeSystem.wanted_stars() == 0, "bail clears the warrant")
	# Bribe: depends entirely on the officer.
	CrimeSystem.commit("shoplift", "loc_scene_g")
	cop.flags["corruption"] = 80
	sheet.cash_cents = 50000
	var bribed := Confrontation.resolve("arrest", "bribe", sheet, cop)
	_check(bribed.success and int(cop.flags.get("bribed_until_day", -1)) >= GameClock.day,
			"the corrupt cop develops amnesia")
	var honest := _mk_npc("w_law2", "loc_scene_g", 100, 10, 80, "cop")
	honest.flags["corruption"] = 5
	var cases_before := WorldState.crime_cases.size()
	var refused := Confrontation.resolve("arrest", "bribe", sheet, honest)
	_check(not refused.success and WorldState.crime_cases.size() == cases_before + 1,
			"bribing the wrong cop is its own crime")
	CrimeSystem._close_warrants()


func _jail_event_kinds() -> Array:
	var kinds: Array = []
	for event_def in CrimeSystem.JAIL_EVENTS:
		kinds.append(str(event_def.get("kind", "")))
	return kinds


func _same_jail_events(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in actual.size():
		var a: Dictionary = actual[i]
		var e: Dictionary = expected[i]
		for key in ["kind", "label", "text", "skill"]:
			if str(a.get(key, "")) != str(e.get(key, "")):
				return false
		for key in ["day", "cash_cents"]:
			if int(a.get(key, -999999)) != int(e.get(key, -999999)):
				return false
		if not is_equal_approx(float(a.get("skill_xp", 0.0)), float(e.get("skill_xp", 0.0))):
			return false
	return true


func _test_pickpocket() -> void:
	print("[Pickpocket: clean lifts and loud failures]")
	var sheet := _fresh_sheet()
	var mark := _mk_npc("w_mark", "loc_scene_h", 90)
	var money_before := mark.money_cents
	var lift := Social.interact(sheet, mark, "pickpocket", 0.0)
	_check(lift.success and sheet.dirty_cents > 0 and mark.money_cents < money_before,
			"clean lift: dirty cash, no case")
	var cases_before := WorldState.crime_cases.size()
	Social.interact(sheet, mark, "pickpocket", 0.999)
	_check(WorldState.crime_cases.size() == cases_before + 1, "getting caught makes a case")
	var saved_minutes := GameClock.total_minutes
	GameClock.total_minutes = 4 * GameClock.MINUTES_PER_DAY + 12 * 60
	var alert := _mk_npc("w_pick_alert", "loc_pick_alert", 50)
	alert.current_activity = "idle"
	var distracted := _mk_npc("w_pick_distracted", "loc_pick_distracted", 50)
	distracted.current_activity = "shopping"
	var watched := _mk_npc("w_pick_watched", "loc_pick_watched", 50)
	watched.current_activity = "shopping"
	_mk_npc("w_pick_eye", "loc_pick_watched", 50)
	var cop_watched := _mk_npc("w_pick_cop_target", "loc_pick_cop", 50)
	cop_watched.current_activity = "shopping"
	_mk_npc("w_pick_cop_eye", "loc_pick_cop", 100, 10, 80, "cop")
	var alert_chance := Social.true_chance(sheet, alert, "pickpocket")
	var distracted_chance := Social.true_chance(sheet, distracted, "pickpocket")
	var watched_chance := Social.true_chance(sheet, watched, "pickpocket")
	var cop_watched_chance := Social.true_chance(sheet, cop_watched, "pickpocket")
	_check(distracted_chance > alert_chance,
			"distracted targets are easier to pickpocket (%.0f%% -> %.0f%%)" % [
				alert_chance * 100.0, distracted_chance * 100.0])
	_check(watched_chance < distracted_chance,
			"nearby eyes make pickpocketing harder")
	_check(cop_watched_chance < watched_chance,
			"cop eyes punish pickpocketing more than bystanders")
	GameClock.total_minutes = 10 * GameClock.MINUTES_PER_DAY + 12 * 60
	var fair_mark := _mk_npc("w_pick_fair", "loc_pick_fair", 50)
	fair_mark.current_activity = "shopping"
	var fair_chance := Social.true_chance(sheet, fair_mark, "pickpocket")
	_check(fair_chance > distracted_chance,
			"FOUNDER'S DAY is a pickpocket paradise")
	WorldState.world_seed = 612030
	WorldState.reset_crime_rng()
	WorldState.town_fear = 50.0
	var before_crime_rng := WorldState.crime_rng_state
	Social.true_chance(sheet, fair_mark, "pickpocket")
	_check(WorldState.crime_rng_state == before_crime_rng,
			"rendering pickpocket odds does not advance crime RNG")
	WorldState.town_fear = 0.0
	GameClock.total_minutes = saved_minutes
	CrimeSystem._close_warrants()


func _test_fence() -> void:
	print("[The fence: 40 cents on the dollar]")
	var sheet := _fresh_sheet()
	sheet.inventory = ["meth", "instant_noodles", "nice_suit"]
	sheet.dirty_cents = 0
	var fence := FenceSpot.new()
	add_child(fence)
	var fence_events := {"money": 0, "path": 0}
	var fence_money_signal := func(_cash_cents: int) -> void:
		fence_events["money"] = int(fence_events.money) + 1
	var fence_path_signal := func() -> void:
		fence_events["path"] = int(fence_events.path) + 1
	EventBus.money_changed.connect(fence_money_signal)
	EventBus.path_updated.connect(fence_path_signal)
	fence.interact(null)
	EventBus.money_changed.disconnect(fence_money_signal)
	EventBus.path_updated.disconnect(fence_path_signal)
	_check(sheet.dirty_cents == int(2000 * 0.4) + int(150 * 0.4),
			"meth + noodles fenced at 40%% ($%.2f)" % (sheet.dirty_cents / 100.0))
	_check(int(fence_events.money) > 0, "fence dirty payout refreshes money UI")
	_check(int(fence_events.path) > 0, "fence sale refreshes path-sensitive inventory")
	_check("nice_suit" in sheet.inventory, "he won't take the suit off your back")
	fence.queue_free()


func _test_dead_npcs() -> void:
	print("[The dead stay dead, everywhere]")
	var corpse: NPCRecord = WorldState.npcs["w_dead"]
	SimEngine._tick_npc(corpse, GameClock.total_minutes, 600)
	_check(corpse.current_activity == "dead", "sim tick parks the dead")
	WorldState.player_location_id = "exterior"
	corpse.current_location_id = "exterior"
	var picks := SimEngine.compute_desired_embodied()
	_check(not picks.has(corpse), "the dead are never embodied")
	WorldState.player_location_id = "exterior"


func _test_save_roundtrip() -> void:
	print("[Save round trip: the law's memory]")
	var case_count := WorldState.crime_cases.size()
	var probe: CrimeCase = WorldState.crime_cases.values()[0]
	var probe_id := probe.id
	var probe_evidence := probe.evidence
	SaveManager.set_in_game(true)
	_check(SaveManager.save_game(), "save_game reports success")
	WorldState.crime_cases.clear()
	WorldState.npcs.clear()
	var ok := SaveManager.load_game()
	_check(ok, "load_game succeeds")
	_check(WorldState.crime_cases.size() == case_count,
			"all cases survive (%d)" % WorldState.crime_cases.size())
	var loaded: CrimeCase = WorldState.crime_cases.get(probe_id)
	_check(loaded != null and is_equal_approx(loaded.evidence, probe_evidence),
			"case evidence survives")
	var corpse: NPCRecord = WorldState.npcs.get("w_dead")
	_check(corpse != null and not corpse.alive, "death survives the save — the town remembers")
	SaveManager.set_in_game(false)
