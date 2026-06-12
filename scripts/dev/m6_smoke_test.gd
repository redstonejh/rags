extends Node
## M6 smoke test — run headless:
##   godot --headless res://scenes/dev/M6SmokeTest.tscn
## Exercises housing + status: the T0-T5 curve and its gates (ID, deposit,
## outfit tier, employment/clean-rent history), the deliberate poverty trap,
## credit drift, buying the house, furniture -> bed quality + Mood, clothing
## as status and disguise, and the save round trip.

var failures: int = 0
var _save_guard := SaveSlotGuard.new()


func _ready() -> void:
	_save_guard.backup()
	var town: Node2D = load("res://scenes/world/Town.tscn").instantiate()
	add_child(town)
	add_child(EconomySystem.new())

	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = "off_the_bus"
	WorldState.new_world(sheet)

	_test_defs()
	_test_poverty_trap()
	_test_gates()
	_test_rent_and_credit()
	_test_buying()
	_test_furniture_and_mood()
	_test_clothing()
	_test_save_roundtrip()
	SaveManager.set_in_game(false)
	_save_guard.restore()
	print("M6 smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)


func _count_path_updates(action: Callable) -> int:
	var events := {"count": 0}
	var signal_handler := func() -> void:
		events["count"] = int(events.count) + 1
	EventBus.path_updated.connect(signal_handler)
	action.call()
	EventBus.path_updated.disconnect(signal_handler)
	return int(events.count)


func _fresh_sheet(origin := "off_the_bus") -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Test Subject"
	sheet.origin_id = origin
	WorldState.player_sheet = sheet
	sheet.rebuild_needs_multipliers()
	return sheet


func _test_defs() -> void:
	print("[Defs: the wealth curve loads]")
	_check(ContentDB.housings.size() >= 6, "6+ housing tiers (%d)" % ContentDB.housings.size())
	_check(ContentDB.furnitures.size() >= 7, "7+ furniture defs (%d)" % ContentDB.furnitures.size())
	var tiers := ContentDB.all_housings().map(func(h: HousingDef) -> int: return h.tier)
	_check(tiers == [0, 1, 2, 3, 4, 5], "tiers sort 0..5")


func _test_poverty_trap() -> void:
	print("[The poverty trap, working as intended]")
	var motel := ContentDB.get_housing("weekly_motel")
	var bricks := ContentDB.get_housing("bricks_unit")
	_check(motel.weekly_rent_cents > bricks.weekly_rent_cents,
			"the motel costs MORE per week than the apartment")
	_check(not motel.requires_id and bricks.requires_id,
			"...but the apartment wants ID")
	_check(bricks.deposit_cents > 0, "...and a deposit")


func _test_gates() -> void:
	print("[Gates: landlords judge]")
	var sheet := _fresh_sheet("rock_bottom") # no papers
	sheet.cash_cents = 100000
	var motel := ContentDB.get_housing("weekly_motel")
	var bricks := ContentDB.get_housing("bricks_unit")
	var decent := ContentDB.get_housing("decent_apartment")
	_check(Housing.rent_blocker(sheet, motel) == "", "no-ID tweaker CAN get the motel")
	_check(Housing.rent_blocker(sheet, bricks) == "needs ID", "the Bricks wants ID")
	sheet.flags["has_id"] = true
	_check(Housing.rent_blocker(sheet, bricks) == "", "ID unlocks the Bricks")
	var blocked := Housing.rent_blocker(sheet, decent)
	_check("dress the part" in blocked or "wks" in blocked,
			"decent apartment still gated (%s)" % blocked)
	sheet.inventory.append("thrift_blazer")
	sheet.flags["outfit"] = "thrift_blazer"
	sheet.flags["weeks_employed"] = 4
	_check(Housing.rent_blocker(sheet, decent) == "",
			"blazer + 4 weeks employed opens the door")
	# Deposit actually leaves the wallet.
	var cash := sheet.cash_cents
	var move_events := _count_path_updates(func() -> void:
		Housing.move_in(sheet, bricks))
	_check(sheet.housing_id == "bricks_unit" and sheet.cash_cents == cash - bricks.deposit_cents,
			"move-in takes the deposit")
	_check(move_events > 0, "move-in refreshes path-sensitive housing state")


func _test_rent_and_credit() -> void:
	print("[Rent Mondays; credit remembers]")
	var sheet := _fresh_sheet()
	sheet.housing_id = "bricks_unit"
	sheet.cash_cents = 20000
	var credit := sheet.credit_score
	var paid_events := _count_path_updates(func() -> void:
		EventBus.day_passed.emit(7))
	_check(sheet.cash_cents == 11000, "bricks rent ($90) charged from the def")
	_check(paid_events > 0, "paid rent refreshes path-sensitive housing state")
	_check(sheet.credit_score == credit + 1, "on-time rent nudges credit up")
	_check(int(sheet.flags.get("clean_rent_weeks", 0)) == 1, "clean rent history counts")
	sheet.cash_cents = 0
	var missed_events := _count_path_updates(func() -> void:
		EventBus.day_passed.emit(14))
	_check(sheet.credit_score == credit + 1 - 5, "missed rent dents credit")
	_check(missed_events > 0, "missed rent refreshes path-sensitive housing state")
	_check(int(sheet.flags.get("clean_rent_weeks", 0)) == 0, "history resets on a miss")
	EventBus.day_passed.emit(21)
	var eviction_events := _count_path_updates(func() -> void:
		EventBus.day_passed.emit(28))
	_check(sheet.housing_id == "", "evicted on strike 3")
	_check(eviction_events > 0, "eviction refreshes path-sensitive housing state")
	_check(sheet.credit_score == credit + 1 - 5 - 5 - 5 - 15, "eviction craters credit")


func _test_buying() -> void:
	print("[Buying the house on Cedar St]")
	var sheet := _fresh_sheet()
	sheet.flags["has_id"] = true
	var house := ContentDB.get_housing("small_house")
	sheet.cash_cents = house.down_payment_cents + 1000
	sheet.credit_score = 30
	_check("credit" in Housing.buy_blocker(sheet, house), "credit 30 can't buy")
	sheet.credit_score = 55
	_check(Housing.buy_blocker(sheet, house) == "", "credit 55 + down payment can")
	var buy_events := _count_path_updates(func() -> void:
		Housing.buy(sheet, house))
	_check(sheet.housing_id == "small_house" and sheet.flags.get("home_owned", false),
			"bought: the mailbox has your name on it")
	_check(sheet.cash_cents == 1000, "20%% down left the wallet")
	_check(buy_events > 0, "home purchase refreshes path-sensitive housing state")


func _test_furniture_and_mood() -> void:
	print("[Furniture: a $30 mattress vs a $3,000 bed]")
	var sheet := _fresh_sheet()
	sheet.housing_id = "bricks_unit"
	_check(is_equal_approx(Housing.furniture_quality(sheet, "bed"), 1.0), "no bed = baseline 1.0")
	sheet.furniture = ["futon", "pillowtop", "crt_tv"]
	_check(is_equal_approx(Housing.furniture_quality(sheet, "bed"), 1.6), "best bed wins (1.6)")
	_check(is_equal_approx(Housing.furniture_quality(sheet, "tv"), 1.0), "CRT is baseline")
	var housed_mood := sheet.mood()
	sheet.housing_id = ""
	var homeless_mood := sheet.mood()
	_check(housed_mood > homeless_mood, "home quality feeds Mood (%.0f vs %.0f)" % [housed_mood, homeless_mood])
	sheet.housing_id = "bricks_unit"


func _test_clothing() -> void:
	print("[Clothing: status + disguise]")
	var sheet := _fresh_sheet()
	_check(sheet.outfit_tier() == 0, "no outfit = tier 0")
	sheet.flags["outfit"] = "nice_suit"
	_check(sheet.outfit_tier() == 3, "the suit projects tier 3")
	# The ski mask kills witness ID...
	var witness := NPCRecord.new()
	witness.id = "w_eyes"
	witness.personality = {"civic_duty": 90, "bravery": 50, "greed": 50,
			"kindness": 50, "chattiness": 50, "jealousy": 10}
	var bare := CrimeSystem.id_confidence(witness, sheet)
	sheet.flags["outfit"] = "ski_mask"
	var masked := CrimeSystem.id_confidence(witness, sheet)
	_check(masked < bare * 0.4, "ski mask guts ID confidence (%.2f -> %.2f)" % [bare, masked])


func _test_save_roundtrip() -> void:
	print("[Save round trip: deeds and dressers]")
	var sheet := _fresh_sheet()
	sheet.housing_id = "small_house"
	sheet.flags["home_owned"] = true
	sheet.flags["outfit"] = "nice_suit"
	sheet.credit_score = 61
	sheet.furniture = ["pillowtop", "sofa"]
	SaveManager.set_in_game(true)
	SaveManager.save_game()
	WorldState.player_sheet = null
	var ok := SaveManager.load_game()
	var s := WorldState.player_sheet
	_check(ok and s != null, "load_game succeeds")
	_check(s.credit_score == 61, "credit survives")
	_check(s.furniture == ["pillowtop", "sofa"], "furniture survives")
	_check(s.flags.get("home_owned", false) and s.housing_id == "small_house", "the deed survives")
	_check(s.outfit_tier() == 3, "the suit survives")
	SaveManager.set_in_game(false)
