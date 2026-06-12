extends Node
## Runs the real Main scene across multiple in-game days with autosaves,
## reloads, and location swaps to catch accumulated state issues.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/LongSessionSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const DAYS_TO_RUN := 10
const RELOAD_DAYS := [3, 7, 10]
const DAILY_LOCATIONS := [
	"loc_diner",
	"exterior",
	"loc_store",
	"loc_bricks",
]

var failures := 0
var _main: Node = null
var _save_guard := SaveSlotGuard.new()
var _seed_before := 0
var _population_before := 0


func _ready() -> void:
	_save_guard.backup()
	_setup_world()
	await _instantiate_main()
	for day_index in range(1, DAYS_TO_RUN + 1):
		await _advance_one_day(day_index)
		if day_index in RELOAD_DAYS:
			await _reload_cycle(day_index)
	_final_checks()
	_finish()


func _finish() -> void:
	_restore_runtime()
	print("Long-session smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Endurance Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 250000
	sheet.housing_id = "bricks_unit"
	sheet.flags["has_id"] = true
	sheet.flags["calories_today"] = 2200
	WorldState.new_world(sheet)
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 8 * 60
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	SaveManager.set_in_game(true)
	_seed_before = WorldState.world_seed
	_population_before = WorldState.npcs.size()


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(_main.get("current_world") != null, "main scene starts for endurance run")


func _advance_one_day(day_index: int) -> void:
	var target_location: String = DAILY_LOCATIONS[(day_index - 1) % DAILY_LOCATIONS.size()]
	EventBus.travel_requested.emit(target_location)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(_current_scene_matches(target_location),
			"day %d location swap remains coherent" % day_index)

	var day_before := GameClock.day
	WorldState.player_sheet.flags["calories_today"] = 2200
	GameClock.skip_minutes(GameClock.MINUTES_PER_DAY)
	await get_tree().process_frame
	await get_tree().physics_frame

	_check(GameClock.day == day_before + 1, "day %d advances exactly one day" % day_index)
	_check(WorldState.player_sheet != null and WorldState.player_sheet.alive,
			"player survives day %d" % day_index)
	_check(WorldState.world_seed == _seed_before and WorldState.npcs.size() == _population_before,
			"town identity stays stable through day %d" % day_index)
	_check(_main.get("current_world") != null and SimEngine.player_node != null,
			"real scene remains wired through day %d" % day_index)
	_check(GameClock.pause_lock_count() == 0 and not GameClock.paused,
			"no modal pause leak after day %d" % day_index)
	_check(SaveManager.has_save(), "autosave exists after day %d" % day_index)
	if day_index >= 2:
		_check(FileAccess.file_exists(SaveManager.SAVE_PATH + ".bak"),
				"autosave keeps a backup after day %d" % day_index)


func _reload_cycle(day_index: int) -> void:
	var expected_day := GameClock.day
	var expected_location := WorldState.player_location_id
	var expected_cash := WorldState.player_sheet.cash_cents
	var expected_clean_rent := int(WorldState.player_sheet.flags.get("clean_rent_weeks", 0))
	var expected_gazette_size := WorldState.gazette.size()
	_teardown_main()
	await get_tree().process_frame

	WorldState.player_sheet = null
	WorldState.npcs.clear()
	WorldState.crime_cases.clear()
	WorldState.player_location_id = "exterior"
	WorldState.world_seed = -1
	GameClock.total_minutes = 0
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)

	var loaded := SaveManager.load_game()
	_check(loaded, "reload succeeds on endurance day %d" % day_index)
	_check(GameClock.day == expected_day, "reload preserves day %d clock" % day_index)
	_check(WorldState.player_location_id == expected_location,
			"reload preserves location on day %d" % day_index)
	_check(WorldState.player_sheet != null and WorldState.player_sheet.cash_cents == expected_cash,
			"reload preserves cash after daily systems on day %d" % day_index)
	_check(WorldState.player_sheet != null \
			and int(WorldState.player_sheet.flags.get("clean_rent_weeks", 0)) == expected_clean_rent,
			"reload preserves rent history after daily systems on day %d" % day_index)
	_check(WorldState.gazette.size() == expected_gazette_size,
			"reload preserves Gazette length on day %d" % day_index)
	await _instantiate_main()
	_check(_current_scene_matches(expected_location),
			"reloaded scene matches saved location on day %d" % day_index)


func _final_checks() -> void:
	var sheet := WorldState.player_sheet
	_check(sheet != null and sheet.cash_cents < 250000,
			"Monday rent was charged during the endurance run")
	_check(sheet != null and int(sheet.flags.get("clean_rent_weeks", 0)) >= 1,
			"clean rent history advanced during the endurance run")
	_check(WorldState.gazette.size() <= WorldState.GAZETTE_CAP,
			"Gazette stays capped during the endurance run")


func _current_scene_matches(location_id: String) -> bool:
	if _main == null or not is_instance_valid(_main):
		return false
	var current_world: Node = _main.get("current_world")
	if location_id == "exterior":
		return WorldState.player_location_id == "exterior" \
				and current_world != null \
				and not (current_world is Interior)
	return WorldState.player_location_id == location_id \
			and current_world is Interior \
			and current_world.location_id == location_id


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null


func _restore_runtime() -> void:
	SaveManager.set_in_game(false)
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	_teardown_main()
	_save_guard.restore()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
