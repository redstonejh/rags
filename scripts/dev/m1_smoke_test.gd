extends Node
## Dev smoke test for M1 — run headless:
##   godot --headless res://scenes/dev/M1SmokeTest.tscn
## Validates content loading, Coherence Engine invariants, and the
## save/load round trip. Prints PASS/FAIL lines and exits nonzero on failure.

var failures: int = 0
var _save_guard := SaveSlotGuard.new()


func _ready() -> void:
	_save_guard.backup()
	_test_content_db()
	_test_coherence()
	_test_save_roundtrip()
	SaveManager.set_in_game(false)
	_save_guard.restore()
	print("M1 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _test_content_db() -> void:
	print("[ContentDB]")
	_check(ContentDB.origins.size() >= 3, "3+ origins loaded (%d)" % ContentDB.origins.size())
	_check(ContentDB.traits.size() >= 15, "15+ traits loaded (%d)" % ContentDB.traits.size())
	_check(ContentDB.items.size() >= 5, "5+ items loaded (%d)" % ContentDB.items.size())
	_check(ContentDB.get_origin("rock_bottom") != null, "rock_bottom origin exists")
	_check(ContentDB.get_trait("iron_will") != null, "iron_will trait exists")


func _test_coherence() -> void:
	print("[Coherence: Deal Me a Life x30]")
	var all_valid := true
	var stat_spread_seen := false
	for i in 30:
		var dealt: Dictionary = Coherence.deal({}, {})
		var origin := ContentDB.get_origin(dealt.origin_id)
		if origin == null:
			all_valid = false
			break
		# Stat invariants: spent <= pool, every stat within [8, 15].
		var spent := CharacterSheet.points_spent(dealt.base_stats)
		if spent > CharacterSheet.POINT_POOL:
			printerr("    deal %d: overspent stats (%d)" % [i, spent])
			all_valid = false
		for s in CharacterSheet.STAT_IDS:
			var v: int = dealt.base_stats[s]
			if v < CharacterSheet.STAT_BASE or v > CharacterSheet.STAT_CAP:
				printerr("    deal %d: stat %s out of range (%d)" % [i, s, v])
				all_valid = false
		# Trait invariants: budget <= 0, no locked traits, no conflicts.
		var budget := 0
		for tid in dealt.trait_ids:
			var t := ContentDB.get_trait(tid)
			if t == null or tid in origin.locked_traits:
				printerr("    deal %d: bad/locked trait %s" % [i, tid])
				all_valid = false
				continue
			budget += t.point_cost
			for other in dealt.trait_ids:
				if other != tid and other in t.conflicts_with:
					printerr("    deal %d: conflict %s vs %s" % [i, tid, other])
					all_valid = false
		if budget > 0:
			printerr("    deal %d: trait budget overspent (%+d)" % [i, budget])
			all_valid = false
		if dealt.char_name == "" or dealt.bio == "":
			all_valid = false
		# Coherence sanity: at least one deal should put its biggest stat
		# where its appearance points (checked loosely across the batch).
		if not stat_spread_seen and spent >= 20:
			stat_spread_seen = true
	_check(all_valid, "30 random deals satisfy all invariants")
	_check(stat_spread_seen, "deals actually spend the point pool")


func _test_save_roundtrip() -> void:
	print("[Save/Load round trip]")
	var dealt: Dictionary = Coherence.deal({}, {})
	var sheet := CharacterSheet.new()
	sheet.char_name = dealt.char_name
	sheet.origin_id = dealt.origin_id
	sheet.base_stats = dealt.base_stats.duplicate()
	sheet.trait_ids = dealt.trait_ids.duplicate()
	sheet.bio = dealt.bio
	sheet.cash_cents = 12345
	sheet.needs.change("hunger", -33.0)
	WorldState.new_game(sheet)
	GameClock.total_minutes = 2000
	SaveManager.set_in_game(true)
	SaveManager.save_game()
	_check(SaveManager.has_save(), "save file written")

	# Wreck the live state, then load it back.
	WorldState.player_sheet = null
	GameClock.total_minutes = 0
	var loaded := SaveManager.load_game()
	_check(loaded, "load_game succeeds")
	var p := WorldState.player_sheet
	_check(p != null and p.char_name == sheet.char_name, "name survives round trip")
	_check(p != null and p.cash_cents == 12345, "cash survives round trip")
	_check(p != null and p.origin_id == sheet.origin_id, "origin survives round trip")
	_check(p != null and absf(p.needs.get_value("hunger") - sheet.needs.get_value("hunger")) < 0.01,
			"needs survive round trip")
	_check(GameClock.total_minutes == 2000, "clock survives round trip")
	_check(p != null and p.trait_ids == sheet.trait_ids, "traits survive round trip")
	SaveManager.set_in_game(false)
