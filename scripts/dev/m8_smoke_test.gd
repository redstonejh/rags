extends Node
## M8 smoke test — run headless:
##   godot --headless res://scenes/dev/M8SmokeTest.tscn
## The living town: it generates its own news, fear changes how it behaves,
## fame/infamy bend the witness math, bodies surface and detectives canvass,
## elections can be bought with dirty money, businesses launder, stats drift
## with lifestyle, three new origins ship with their baggage, and perks
## unlock new verbs. Then it all round-trips through a save.

var failures: int = 0
var _town_life: TownLife
var _economy: EconomySystem


func _ready() -> void:
	var town: Node2D = load("res://scenes/world/Town.tscn").instantiate()
	add_child(town)
	_town_life = TownLife.new()
	add_child(_town_life)
	_economy = EconomySystem.new()
	add_child(_economy)
	add_child(CrimeSystem.new())
	add_child(ShiftSystem.new())

	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_world(sheet)

	_test_content()
	_test_town_news()
	_test_fear()
	_test_fame_infamy()
	_test_bodies_and_detectives()
	_test_election()
	_test_business()
	_test_stat_drift()
	_test_new_origins()
	_test_perks()
	_test_holidays()
	_test_save_roundtrip()
	print("M8 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _fresh_sheet(origin := "off_the_bus") -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = origin
	WorldState.player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	return sheet


func _mk_npc(id: String, loc: String, civic: int) -> NPCRecord:
	var n := NPCRecord.new()
	n.id = id
	n.display_name = "Probe %s" % id
	n.archetype_id = "barfly"
	n.appearance_tags = ["plain"]
	for s in CharacterSheet.STAT_IDS:
		n.stats[s] = 8
	n.personality = {"bravery": 50, "greed": 50, "civic_duty": civic,
			"kindness": 50, "chattiness": 50, "jealousy": 10}
	n.home_id = "loc_bricks"
	n.current_location_id = loc
	n.current_activity = "idle"
	n.money_cents = 10000
	WorldState.npcs[n.id] = n
	return n


func _test_content() -> void:
	print("[Content: the full roster]")
	_check(ContentDB.origins.size() >= 6, "6 origins shipped (%d)" % ContentDB.origins.size())
	_check(ContentDB.perks.size() >= 4, "4 perks shipped (%d)" % ContentDB.perks.size())
	_check(TownLife.BUSINESSES.size() >= 2, "2 buyable businesses")


func _test_town_news() -> void:
	print("[Do nothing for a week; the town makes news]")
	var before := WorldState.gazette.size()
	for d in 7:
		EventBus.day_passed.emit(100 + d) # mid-cycle days, no election
	_check(WorldState.gazette.size() > before, "the Gazette filled itself (%d items)" % WorldState.gazette.size())
	_check(WorldState.gazette.size() <= WorldState.GAZETTE_CAP, "archive capped")


func _test_fear() -> void:
	print("[Town fear: the murder-hobo equilibrium]")
	var sheet := _fresh_sheet()
	WorldState.town_fear = 0.0
	_mk_npc("f_w1", "loc_fear_scene", 90)
	CrimeSystem.commit("armed_robbery", "loc_fear_scene")
	_check(WorldState.town_fear > 0.0, "witnessed crime raises fear (%.1f)" % WorldState.town_fear)
	var fear_now := WorldState.town_fear
	EventBus.day_passed.emit(101)
	_check(WorldState.town_fear < fear_now + 3.0, "fear decays daily (one of these days was quiet)")
	# At fear 40+, the streets empty: fewer witnesses, on purpose.
	WorldState.town_fear = 50.0
	for i in 10:
		_mk_npc("f_crowd_%d" % i, "loc_crowded", 50)
	var thinned := false
	for _i in 30:
		if CrimeSystem.witnesses_at("loc_crowded").size() < 10:
			thinned = true
	_check(thinned, "fear 40+ thins the witness pool")
	WorldState.town_fear = 0.0
	CrimeSystem._close_warrants()


func _test_fame_infamy() -> void:
	print("[Fame opens doors; infamy closes mouths]")
	var sheet := _fresh_sheet()
	_mk_npc("fi_cop", "loc_fame_scene", 100).archetype_id = "cop"
	CrimeSystem.commit("armed_robbery", "loc_fame_scene")
	_check(sheet.infamy > 0.0, "a warrant makes you infamous (%.0f)" % sheet.infamy)
	_check(sheet.flags.has("last_warrant_day"), "the parole clock knows")
	# Infamy terrifies witnesses out of reporting.
	var witness := _mk_npc("fi_wit", "loc_quiet", 70)
	sheet.infamy = 0.0
	_check(CrimeSystem.decides_to_report(witness, false), "civic 70 reports a nobody")
	sheet.infamy = 90.0
	_check(not CrimeSystem.decides_to_report(witness, false), "civic 70 stays quiet about a monster")
	sheet.infamy = 0.0
	CrimeSystem._close_warrants()


func _test_bodies_and_detectives() -> void:
	print("[Bodies surface; murder cases never expire]")
	var sheet := _fresh_sheet()
	var case := CrimeSystem.commit("murder", "loc_nobody_around")
	_check(case.status == CrimeCase.UNREPORTED, "unwitnessed murder starts silent")
	var found := false
	for _d in 100:
		CrimeSystem._bodies_and_detectives()
		if case.status != CrimeCase.UNREPORTED:
			found = true
			break
	_check(found, "the body is discovered eventually")
	var warranted := false
	for _d in 40:
		CrimeSystem._bodies_and_detectives()
		if case.status == CrimeCase.WARRANT:
			warranted = true
			break
	_check(warranted, "detectives canvass it into a warrant")
	_check(sheet.infamy > 0.0, "a murder warrant is real infamy")
	CrimeSystem._close_warrants()
	EventBus.wanted_changed.emit(CrimeSystem.wanted_stars())


func _test_election() -> void:
	print("[Run for mayor on dirty money]")
	var sheet := _fresh_sheet()
	sheet.dirty_cents = 700000 # $7,000 of the other kind
	for _i in 7:
		TownLife.donate_to_campaign(sheet, 100000)
	_check(sheet.dirty_cents == 0, "the campaign laundered itself")
	_check(is_equal_approx(TownLife.player_election_score(sheet), 35.0),
			"$7k buys 35 points of electability")
	_town_life._election_day()
	_check(sheet.flags.get("is_mayor", false), "UPSET AT CITY HALL: you won")
	_check(sheet.fame >= 15.0, "winning is famous")
	var found_news := false
	for item in WorldState.gazette:
		if "CITY HALL" in str(item.text):
			found_news = true
	_check(found_news, "the Gazette covered it")


func _test_business() -> void:
	print("[The laundromat: why criminals do laundry]")
	var sheet := _fresh_sheet()
	sheet.cash_cents = 2500000
	sheet.dirty_cents = 100000
	_check(TownLife.buy_business(sheet, "laundromat"), "bought Suds City")
	_check(sheet.cash_cents == 0, "it cost every clean cent")
	WorldState.town_fear = 0.0
	_town_life._business_day()
	_check(sheet.dirty_cents == 50000, "washed the daily cap ($500)")
	_check(sheet.cash_cents == 6000 + 40000, "net income + laundered 80%% ($60 + $400)")


func _test_stat_drift() -> void:
	print("[Stat drift: the gym vs the library]")
	var sheet := _fresh_sheet()
	sheet.flags["drift_phys"] = 12.0
	sheet.flags["drift_mind"] = 0.0
	_economy._stat_drift(sheet)
	_check(int(sheet.base_stats["STR"]) == 9 and int(sheet.base_stats["INT"]) == 7,
			"gym life: STR +1, INT -1 — you stopped reading")
	sheet.flags["drift_mind"] = 15.0
	sheet.flags["drift_phys"] = 0.0
	_economy._stat_drift(sheet)
	_check(int(sheet.base_stats["INT"]) == 8, "night classes pull it back")


func _test_new_origins() -> void:
	print("[New origins: the Ex-Con, the Gambler, the Doctor]")
	var con := _fresh_sheet("fresh_out")
	_check(con.has_tag("the_record"), "the Ex-Con carries The Record")
	_check(ContentDB.get_job("office_assistant").requires_clean_record,
			"office jobs run background checks")
	con.flags["parole_start_day"] = GameClock.day - 14
	Body.daily_tick(con)
	_check(con.flags.get("record_sealed", false), "14 clean days seal the record")
	var going := false
	for p in LifePaths.evaluate(con):
		if str(p.name) == "Going Straight":
			going = p.steps[2].done
	_check(going, "Going Straight path completes")

	var doc := _fresh_sheet("struck_off")
	doc.skills = ContentDB.get_origin("struck_off").skill_seeds.duplicate()
	Body.substance_state(doc, "oxy").addiction = 0.4 # creation does this via tag
	_check(doc.skill_level("medicine") >= 1, "the hands still remember")
	_check(doc.has_tag("garnished"), "the loans survived the scandal")
	doc.job_id = "dishwasher"
	var cash0 := doc.cash_cents
	EventBus.shift_finished.emit(ContentDB.get_job("dishwasher"), 0)
	_check(doc.cash_cents == cash0 + int(5400 * 0.75), "25%% garnished, forever ($40.50)")

	var gambler := ContentDB.get_origin("one_more_hand")
	_check("luck" in gambler.tags and int(gambler.starting_flags.get("mickey_debt", 0)) == 1500000,
			"the Gambler: luck is real, and so is the $15k")


func _test_perks() -> void:
	print("[Perks: new verbs every two levels]")
	var sheet := _fresh_sheet()
	var path_events := {"count": 0}
	var on_path := func() -> void:
		path_events["count"] = int(path_events.count) + 1
	EventBus.path_updated.connect(on_path)
	sheet.add_xp(100) # level 2
	_check(sheet.level == 2 and int(sheet.flags.get("perk_points", 0)) == 1,
			"level 2 grants a perk point")
	_check(int(path_events.count) > 0, "leveling refreshes path/perk UI")
	var mark := _mk_npc("p_mark", "loc_perk_room", 50)
	var before := Social.true_chance(sheet, mark, "compliment")
	path_events["count"] = 0
	_check(sheet.take_perk("silver_tongue"), "took Silver Tongue")
	_check(int(path_events.count) > 0, "taking a perk refreshes path/perk UI")
	EventBus.path_updated.disconnect(on_path)
	_check(Social.true_chance(sheet, mark, "compliment") > before, "+5%% on every social roll")
	# The top of the perception tree: truth, finally.
	sheet.level = 6
	sheet.flags["perk_points"] = 1
	sheet.take_perk("people_reader")
	_check(is_equal_approx(Perception.accuracy(sheet), 1.0), "People Reader sees TRUE stats")


func _test_holidays() -> void:
	print("[The calendar has opinions]")
	var saved := GameClock.total_minutes
	GameClock.total_minutes = 20 * GameClock.MINUTES_PER_DAY + 600
	_check(TownLife.holiday_today() == "GRISTMAS", "GRISTMAS lands on schedule")
	GameClock.total_minutes = 30 * GameClock.MINUTES_PER_DAY + 600
	_check(TownLife.holiday_today() == "ALL HALLOWS", "ALL HALLOWS too")
	var sheet := _fresh_sheet()
	var witness := _mk_npc("h_wit", "loc_hallows", 90)
	var conf := CrimeSystem.id_confidence(witness, sheet)
	_check(conf <= 0.45, "masks are normal for one night (ID conf %.2f)" % conf)
	GameClock.total_minutes = saved


func _test_save_roundtrip() -> void:
	print("[Save round trip: the town's whole memory]")
	var sheet := _fresh_sheet()
	sheet.fame = 33.0
	sheet.infamy = 12.0
	sheet.flags["is_mayor"] = true
	sheet.flags["businesses"] = ["laundromat"]
	sheet.add_xp(100)
	sheet.flags["perk_points"] = 1
	sheet.take_perk("iron_liver")
	WorldState.town_fear = 17.0
	var news_count := WorldState.gazette.size()
	SaveManager.set_in_game(true)
	SaveManager.save_game()
	WorldState.player_sheet = null
	WorldState.gazette = []
	WorldState.town_fear = 0.0
	var ok := SaveManager.load_game()
	var s := WorldState.player_sheet
	_check(ok and s != null, "load_game succeeds")
	_check(is_equal_approx(s.fame, 33.0) and is_equal_approx(s.infamy, 12.0), "fame/infamy survive")
	_check(s.flags.get("is_mayor", false), "the office survives")
	_check("laundromat" in s.flags.get("businesses", []), "the business survives")
	_check(s.has_perk("iron_liver") and s.level == 2, "perks and level survive")
	_check(WorldState.gazette.size() == news_count, "the Gazette archive survives (%d)" % WorldState.gazette.size())
	_check(is_equal_approx(WorldState.town_fear, 17.0), "town fear survives")
	SaveManager.set_in_game(false)
