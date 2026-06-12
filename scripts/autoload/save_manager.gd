extends Node
## Versioned JSON save/load. Ironman model: one autosaving slot per world.
## Saves only mutable state (WorldState + GameClock) — definitions never.
## Crash-safe: write .tmp, then rename over the real file, keep one .bak.

const SAVE_DIR := "user://saves"
const SAVE_PATH := SAVE_DIR + "/world.json"
const SAVE_VERSION := 1

var _in_game: bool = false
var _autosave_queued: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# Ironman cadence: autosave at the top of every game day and on quit.
	EventBus.day_passed.connect(_queue_daily_autosave)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _in_game:
		save_game()


func set_in_game(value: bool) -> void:
	_in_game = value


func _queue_daily_autosave(_day: int) -> void:
	if _autosave_queued:
		return
	_autosave_queued = true
	call_deferred("_run_daily_autosave")


func _run_daily_autosave() -> void:
	_autosave_queued = false
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if not _in_game or WorldState.player_sheet == null:
		return
	var data := {
		"save_version": SAVE_VERSION,
		"clock": GameClock.to_dict(),
		"world": WorldState.to_dict(),
	}
	var json := JSON.stringify(data, "\t")

	var tmp_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s" % tmp_path)
		return
	f.store_string(json)
	f.close()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	DirAccess.rename_absolute(tmp_path, SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: corrupt save file")
		return false
	var data: Dictionary = _migrate(parsed)
	GameClock.load_dict(data.get("clock", {}))
	WorldState.load_dict(data.get("world", {}))
	return WorldState.player_sheet != null


## Migration chain: each step upgrades one version. New fields should also
## be defaulted in every from_dict, so this mostly handles renames/moves.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 1))
	while version < SAVE_VERSION:
		match version:
			_:
				pass
		version += 1
	data["save_version"] = SAVE_VERSION
	return data
