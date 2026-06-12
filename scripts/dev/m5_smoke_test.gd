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


func _ready() -> void:
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
	_test_arrest_paths()
	_test_pickpocket()
	_test_fence()
	_test_dead_npcs()
	_test_save_roundtrip()
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
	Confrontation.resolve("standoff_win", "rob", sheet, pushover)
	_check(sheet.dirty_cents > dirty_before, "robbery pays dirty")
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


func _test_arrest_paths() -> void:
	print("[Arrest: comply / bail / bribe]")
	# Comply: serve shoplift's 1-day minimum; clock moves, warrants clear.
	var sheet := _fresh_sheet()
	_mk_npc("w_law1", "loc_scene_g", 100, 10, 80, "cop")
	CrimeSystem.commit("shoplift", "loc_scene_g")
	var cop: NPCRecord = WorldState.npcs["w_law1"]
	var day_before := GameClock.day
	var result := Confrontation.resolve("arrest", "comply", sheet, cop)
	_check(result.success and GameClock.day == day_before + 1, "served 1 day for shoplifting")
	_check(CrimeSystem.wanted_stars() == 0, "warrants cleared by serving")
	_check(float(sheet.skills.get("fitness", 0.0)) > 0.0, "yard weights: fitness XP in jail")
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
	CrimeSystem._close_warrants()


func _test_fence() -> void:
	print("[The fence: 40 cents on the dollar]")
	var sheet := _fresh_sheet()
	sheet.inventory = ["meth", "instant_noodles", "nice_suit"]
	sheet.dirty_cents = 0
	var fence := FenceSpot.new()
	add_child(fence)
	fence.interact(null)
	_check(sheet.dirty_cents == int(2000 * 0.4) + int(150 * 0.4),
			"meth + noodles fenced at 40%% ($%.2f)" % (sheet.dirty_cents / 100.0))
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
	SaveManager.save_game()
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
