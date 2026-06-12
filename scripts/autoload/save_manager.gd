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


func save_game() -> bool:
	if not _in_game or WorldState.player_sheet == null:
		return false
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
		return false
	f.store_string(json)
	f.close()

	if FileAccess.file_exists(SAVE_PATH):
		var backup_err := DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		if backup_err != OK:
			_remove_if_exists(tmp_path)
			push_error("SaveManager: cannot back up %s (%d)" % [SAVE_PATH, backup_err])
			return false
	var rename_err := DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if rename_err != OK and FileAccess.file_exists(SAVE_PATH):
		var remove_err := DirAccess.remove_absolute(SAVE_PATH)
		if remove_err == OK:
			rename_err = DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if rename_err != OK:
		_remove_if_exists(tmp_path)
		push_error("SaveManager: cannot replace %s (%d)" % [SAVE_PATH, rename_err])
		return false
	return true


func load_game() -> bool:
	if not has_save() and not FileAccess.file_exists(SAVE_PATH + ".bak"):
		return false
	var data := _read_save_file(SAVE_PATH)
	if data.is_empty():
		data = _read_save_file(SAVE_PATH + ".bak")
	if data.is_empty():
		push_error("SaveManager: no readable save file")
		return false
	data = _migrate(data)
	GameClock.load_dict(data.get("clock", {}))
	WorldState.load_dict(data.get("world", {}))
	return WorldState.player_sheet != null


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parser := JSON.new()
	var err := parser.parse(f.get_as_text())
	if err != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: cannot read %s (%s at line %d)" % [
			path, parser.get_error_message(), parser.get_error_line()])
		return {}
	return parser.data


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


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
