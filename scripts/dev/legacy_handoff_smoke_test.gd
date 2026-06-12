extends Node
## Exercises the post-Walk-Away handoff through the real character creation UI.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/LegacyHandoffSmokeTest.tscn

const CHARACTER_CREATION_SCENE := preload("res://scenes/ui/CharacterCreation.tscn")

var failures := 0


func _ready() -> void:
	_setup_walked_away_world()
	await _test_character_creation_rejoins_existing_town()
	print("Legacy handoff smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_walked_away_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "First Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 50000
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)


func _test_character_creation_rejoins_existing_town() -> void:
	print("[Post-Walk-Away character creation]")
	var seed_before := WorldState.world_seed
	var population_before := WorldState.npcs.size()
	var previous_life_number := WorldState.player_sheet.lives_lived
	var old_self := WorldState.walk_away()
	_check(old_self != null and not WorldState.player_sheet.alive,
			"Walk Away leaves an ended life and old-self NPC")
	_check(WorldState.npcs.size() == population_before + 1,
			"old-self NPC joins the existing town")

	var creation: Control = CHARACTER_CREATION_SCENE.instantiate()
	add_child(creation)
	await get_tree().process_frame
	await get_tree().process_frame
	var header := creation.get_node("Margin/Root/Header") as Label
	_check(header != null and "Life #%d" % (previous_life_number + 1) in header.text \
			and "Rust Harbor" in header.text,
			"character creation labels the next life in the same town")
	await _test_origin_detail_summary(creation)

	var name_edit := creation.get_node("%NameEdit") as LineEdit
	var start_button := creation.get_node("%StartButton") as Button
	name_edit.text = "Second Chance"
	creation.call("_refresh")
	_check(start_button != null and not start_button.disabled,
			"new-life start button enables after a valid name")
	if start_button == null or start_button.disabled:
		return
	start_button.pressed.emit()
	_check(WorldState.player_sheet != null and WorldState.player_sheet.char_name == "Second Chance",
			"character creation installs the next player sheet")
	_check(WorldState.player_sheet.lives_lived == previous_life_number + 1,
			"next life increments the life counter")
	_check(WorldState.world_seed == seed_before and WorldState.npcs.has(old_self.id),
			"next life keeps the existing town and old self")


func _test_origin_detail_summary(creation: Control) -> void:
	for origin in ContentDB.all_origins():
		creation.call("_select_origin", origin.id)
		await get_tree().process_frame
		_check_origin_detail_summary(creation, origin)


func _check_origin_detail_summary(creation: Control, origin: OriginDef) -> void:
	var info := creation.get_node("%OriginInfo") as RichTextLabel
	var text := info.text if info else ""
	var start_name := Locations.display_name(origin.starting_location_id)
	var id_text := "No ID" if origin.tags.has("no_papers") else "Has ID"
	_check(origin.opening_line in text,
			"%s details show the authored arrival beat" % origin.id)
	_check("[b]Start:[/b] %s" % start_name in text \
			and "[b]Housing:[/b]" in text and "[b]Gear:[/b]" in text,
			"%s details summarize start location, housing, and gear" % origin.id)
	_check("[b]Legal ID:[/b]" in text and id_text in text,
			"%s details summarize legal ID status" % origin.id)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
