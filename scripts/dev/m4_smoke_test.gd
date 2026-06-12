extends Node
## M4 smoke test — run headless:
##   godot --headless res://scenes/dev/M4SmokeTest.tscn
## Exercises social + perception: perceived-vs-true stat reads, visible-odds
## interaction math, the Reality Check moment (90% becomes 0%, in public),
## witnesses, gossip propagation ("a stranger knows two days later"),
## memory decay/caps, dating, and the save round trip of all of it.

var failures: int = 0
var _rc_fired: Array = []
var _travel_requests: Array[String] = []


func _ready() -> void:
	var town: Node2D = load("res://scenes/world/Town.tscn").instantiate()
	add_child(town)
	add_child(GossipSystem.new())
	EventBus.reality_check.connect(func(p: float, a: float, npc_id: String) -> void:
		_rc_fired.append([p, a, npc_id]))
	EventBus.travel_requested.connect(func(location_id: String) -> void:
		_travel_requests.append(location_id))

	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_world(sheet)

	_test_perception_gap()
	_test_streetwise_reads()
	_test_reality_check()
	_test_relationship_deltas()
	_test_social_odds_balance()
	_test_gossip()
	_test_memory_hygiene()
	_test_dating()
	_test_save_roundtrip()
	print("M4 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _mk_npc(id: String, loc: String, appearance: Array, str_val: int,
		bravery: int, chattiness: int) -> NPCRecord:
	var n := NPCRecord.new()
	n.id = id
	n.display_name = "Probe %s" % id
	n.archetype_id = "barfly"
	n.appearance_tags = appearance
	for s in CharacterSheet.STAT_IDS:
		n.stats[s] = 8
	n.stats["STR"] = str_val
	n.personality = {"bravery": bravery, "greed": 50, "civic_duty": 50,
			"kindness": 50, "chattiness": chattiness, "jealousy": 10}
	n.home_id = "loc_bricks"
	n.current_location_id = loc
	n.current_activity = "idle"
	WorldState.npcs[n.id] = n
	return n


func _fresh_viewer() -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Viewer"
	sheet.origin_id = "off_the_bus"
	WorldState.player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	return sheet


func _test_perception_gap() -> void:
	print("[Perception: the guess vs the truth]")
	# The librarian who boxes: looks bookish, is STR 15.
	var librarian := _mk_npc("npc_lib", "loc_test_room", ["bookish", "glasses"], 15, 50, 50)
	librarian.is_subversion = true
	var dim := _fresh_viewer() # INT 8, streetwise 0
	var seen_dim: Dictionary = Perception.perceived_stats(dim, librarian)
	_check(int(seen_dim["STR"]) < 12, "oblivious viewer buys the stereotype (sees STR %d)" % seen_dim["STR"])
	var sharp := _fresh_viewer()
	sharp.skills["streetwise"] = 400.0 # level 8: prison tattoos, favored knee
	var seen_sharp: Dictionary = Perception.perceived_stats(sharp, librarian)
	_check(int(seen_sharp["STR"]) >= 13, "streetwise viewer sees through it (sees STR %d)" % seen_sharp["STR"])
	_check(int(Perception.stereotype_stats(["buff"])["STR"]) >= 12, "buff advertises STR")


func _test_streetwise_reads() -> void:
	print("[Streetwise: the internal monologue]")
	var librarian: NPCRecord = WorldState.npcs["npc_lib"]
	var dim := _fresh_viewer()
	var low_read := Perception.read_line(dim, librarian)
	_check(low_read in Perception._LOW_READS, "low streetwise reads nothing (\"%s\")" % low_read)
	var sharp := _fresh_viewer()
	sharp.skills["streetwise"] = 160.0
	var high_read := Perception.read_line(sharp, librarian)
	_check("off" in high_read, "high streetwise smells the subversion")
	var reader := _fresh_viewer()
	reader.perk_ids.append("people_reader")
	var reader_line := Perception.read_line(reader, librarian)
	_check("People Reader:" in reader_line and "STR 15" in reader_line,
			"People Reader exposes true stats in the read line")


func _test_reality_check() -> void:
	print("[Reality Check: confidence meets fact]")
	# Engineered hard miss: drunk viewer, STR 13 + a little streetwise,
	# target reads plain (perceived STR ~10) but is truly STR 15, bravery 50.
	var mark := _mk_npc("npc_mark", "loc_test_room", ["plain"], 15, 50, 50)
	var witness := _mk_npc("npc_wit", "loc_test_room", ["plain"], 8, 50, 90)
	var viewer := _fresh_viewer()
	viewer.base_stats["STR"] = 13
	viewer.skills["streetwise"] = 10.0 # level 1
	viewer.flags["drunk_minutes"] = 60
	_rc_fired.clear()
	var result: Dictionary = Social.interact(viewer, mark, "threaten", 0.99)
	_check(result.perceived >= 0.70, "displayed odds were confident (%d%%)" % roundi(result.perceived * 100))
	_check(result.actual <= 0.35, "true odds were terrible (%d%%)" % roundi(result.actual * 100))
	_check(not result.success and result.reality_check, "the swing missed: Reality Check fires")
	_check(_rc_fired.size() == 1 and _rc_fired[0][2] == "npc_mark", "reality_check signal emitted")
	var saw := false
	for m in witness.memories:
		if m.kind == "witnessed" and "misjudge" in str(m.text):
			saw = true
	_check(saw, "the witness will remember this forever")
	_check(witness.rel("player") < 0.0, "the witness thinks less of you now")
	_check(int(witness.flags.get("reacting_until_min", -1)) > GameClock.total_minutes \
			and witness.flags.get("reaction_target_id", "") == mark.id,
			"the witness visibly reacts to the Reality Check")


func _test_relationship_deltas() -> void:
	print("[Relationships: words have prices]")
	var mark: NPCRecord = WorldState.npcs["npc_mark"]
	var viewer := _fresh_viewer()
	mark.relationships["player"] = 0.0
	Social.interact(viewer, mark, "compliment", 0.0) # forced success
	_check(mark.rel("player") > 0.0, "compliment success raises relationship (%.1f)" % mark.rel("player"))
	var before := mark.rel("player")
	Social.interact(viewer, mark, "insult")
	_check(mark.rel("player") <= before - 15.0, "insult costs 15 (%.1f)" % mark.rel("player"))
	_check(mark.memories.any(func(m: Dictionary) -> bool: return m.kind == "insult"),
			"the insult is now a memory")


func _test_social_odds_balance() -> void:
	print("[Odds balance: social math stays in sane bands]")
	var mark := _mk_npc("npc_odds", "loc_test_room", ["plain"], 8, 50, 50)
	var baseline := _fresh_viewer()
	var baseline_chance := Social.true_chance(baseline, mark, "compliment")
	_check(baseline_chance >= 0.45 and baseline_chance <= 0.55,
			"average stranger compliment sits near even odds (%d%%)" % roundi(baseline_chance * 100))

	var smooth := _fresh_viewer()
	smooth.base_stats["CHA"] = 10
	smooth.skills["persuasion"] = 60.0
	smooth.perk_ids.append("silver_tongue")
	mark.relationships["player"] = 50.0
	var smooth_chance := Social.true_chance(smooth, mark, "compliment")
	_check(smooth_chance > baseline_chance + 0.20 and smooth_chance < 0.95,
			"skill, warmth, and Silver Tongue help without auto-winning (%d%%)" % roundi(smooth_chance * 100))

	var disliked := _fresh_viewer()
	disliked.base_stats["CHA"] = 6
	mark.relationships["player"] = -80.0
	var disliked_chance := Social.true_chance(disliked, mark, "compliment")
	_check(disliked_chance < baseline_chance - 0.20,
			"bad stats and hostility materially hurt the roll (%d%%)" % roundi(disliked_chance * 100))


func _test_gossip() -> void:
	print("[Gossip: a stranger knows two days later]")
	var witness: NPCRecord = WorldState.npcs["npc_wit"]
	var stranger := _mk_npc("npc_str", "loc_test_room", ["plain"], 8, 50, 50)
	var ok := GossipSystem.share(witness, stranger)
	_check(ok, "witness shares the juiciest story")
	var heard: Dictionary = {}
	for m in stranger.memories:
		if m.get("secondhand", false) and m.get("subject", "") == "player":
			heard = m
	_check(not heard.is_empty(), "stranger now holds a secondhand memory about the player")
	_check(str(heard.get("source_id", "")) == witness.id, "secondhand gossip records who said it")
	_check(float(heard.get("salience", 0)) < 10.0, "gossip arrives degraded")
	_check(stranger.rel("player") < 0.0, "stranger's opinion moved by a story alone")
	# Two days pass; the story survives decay and comes up in conversation.
	GossipSystem.decay_memories(stranger)
	GossipSystem.decay_memories(stranger)
	var viewer := _fresh_viewer()
	var chat: Dictionary = Social.interact(viewer, stranger, "chat")
	_check(witness.display_name in str(chat.text), "the stranger names who told them")
	# Hourly propagation also works end-to-end (random speakers, many ticks).
	var quiet := _mk_npc("npc_qt", "loc_test_room2", ["plain"], 8, 50, 95)
	quiet.add_memory("witnessed", "player", "saw something unrepeatable", -0.5, 12.0)
	var fresh := _mk_npc("npc_fr", "loc_test_room2", ["plain"], 8, 50, 5)
	for _i in 40:
		EventBus.hour_passed.emit(12)
	_check(fresh.memories.any(func(m: Dictionary) -> bool: return m.get("secondhand", false)),
			"hourly tick propagates gossip between co-located NPCs")
	_check(fresh.rel(quiet.id) != 0.0, "talking builds familiarity (drift %.1f)" % fresh.rel(quiet.id))


func _test_memory_hygiene() -> void:
	print("[Memory: salience decay + cap]")
	var n := _mk_npc("npc_mem", "loc_test_room3", ["plain"], 8, 50, 50)
	for i in 30:
		n.add_memory("noise", "player", "minor thing %d" % i, 0.0, 2.0 + i * 0.1)
	_check(n.memories.size() <= NPCRecord.MEMORY_CAP, "memory capped at %d" % NPCRecord.MEMORY_CAP)
	n.memories = [{"kind": "noise", "subject": "x", "text": "t", "tone": 0.0, "salience": 1.6, "day": 1, "secondhand": false}]
	GossipSystem.decay_memories(n)
	_check(n.memories.is_empty(), "boring memories evaporate")


func _test_dating() -> void:
	print("[Dating: the optimistic path]")
	var mark: NPCRecord = WorldState.npcs["npc_mark"]
	mark.relationships["player"] = 50.0
	mark.flags.erase("dating_player")
	var viewer := _fresh_viewer()
	_check("ask_out" in Social.available_actions(viewer, mark), "ask out unlocks at 40+")
	Social.interact(viewer, mark, "ask_out", 0.0) # forced yes
	_check(mark.flags.get("dating_player", false), "they said yes")
	var actions := Social.available_actions(viewer, mark)
	_check("date_mels" in actions and "date_anchor" in actions and "ask_out" not in actions,
			"dating swaps ask-out for named date activities")
	var scene := Social.date_scene("date_mels")
	_check(scene.has("choices") and scene.choices.size() >= 3,
			"date activity opens a venue scene with choices")
	var before := mark.rel("player")
	WorldState.player_location_id = "exterior"
	_travel_requests.clear()
	Social.interact(viewer, mark, "date_mels_listen")
	_check(mark.rel("player") > before, "date activity compounds the relationship")
	_check(_travel_requests == ["loc_diner"], "date activity requests venue travel")
	_check(WorldState.player_location_id == "loc_diner" and mark.current_location_id == "loc_diner",
			"date activity moves the couple to the venue")
	_check(mark.memories.any(func(m: Dictionary) -> bool:
		return m.get("kind", "") == "date" and "Mel's" in str(m.get("text", ""))),
			"date activity leaves a specific memory")

	var talker := _mk_npc("npc_date_talker", "loc_diner", ["plain"], 8, 50, 90)
	var quiet := _mk_npc("npc_date_quiet", "loc_diner", ["plain"], 8, 50, 10)
	talker.relationships["player"] = 50.0
	quiet.relationships["player"] = 50.0
	WorldState.player_location_id = "loc_diner"
	var talk_text := str(Social.interact(viewer, talker, "date_mels_listen").text)
	var quiet_text := str(Social.interact(viewer, quiet, "date_mels_listen").text)
	_check(talker.rel("player") > quiet.rel("player"),
			"personality shapes date choice relationship gains")
	_check("more to say" in talk_text and "do not pry" in quiet_text,
			"date result text reflects personality fit")


func _test_save_roundtrip() -> void:
	print("[Save round trip: the town remembers]")
	var mark: NPCRecord = WorldState.npcs["npc_mark"]
	var mem_count := mark.memories.size()
	var rel := mark.rel("player")
	SaveManager.set_in_game(true)
	SaveManager.save_game()
	WorldState.npcs.clear()
	WorldState.player_sheet = null
	var ok := SaveManager.load_game()
	_check(ok, "load_game succeeds")
	var loaded: NPCRecord = WorldState.npcs.get("npc_mark")
	_check(loaded != null and loaded.memories.size() == mem_count,
			"memories survive the round trip (%d)" % (loaded.memories.size() if loaded else -1))
	_check(loaded != null and is_equal_approx(loaded.rel("player"), rel),
			"relationships survive")
	_check(loaded != null and loaded.flags.get("dating_player", false),
			"the relationship status survives")
	SaveManager.set_in_game(false)
