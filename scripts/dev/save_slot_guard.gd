class_name SaveSlotGuard
extends RefCounted
## Temporarily preserves the ironman save slot while smoke tests write to it.

const SAVE_FILES := [
	SaveManager.SAVE_PATH,
	SaveManager.SAVE_PATH + ".bak",
]
const BACKUP_SUFFIX := ".smoke_backup"
const LOCK_DIR := SaveManager.SAVE_DIR + "/.smoke_save_lock"
const LOCK_TIMEOUT_MSEC := 120000
const LOCK_POLL_MSEC := 100

var _had_file := {}
var _has_lock := false


func backup() -> void:
	_acquire_lock()
	for path in SAVE_FILES:
		_had_file[path] = FileAccess.file_exists(path)
		_remove_if_exists(_backup_path(path))
		if bool(_had_file[path]):
			var err := DirAccess.copy_absolute(path, _backup_path(path))
			if err != OK:
				push_error("SaveSlotGuard: cannot back up %s (%d)" % [path, err])


func restore() -> void:
	for path in SAVE_FILES:
		_remove_if_exists(path)
		if bool(_had_file.get(path, false)):
			if FileAccess.file_exists(_backup_path(path)):
				var err := DirAccess.copy_absolute(_backup_path(path), path)
				if err != OK:
					push_error("SaveSlotGuard: cannot restore %s (%d)" % [path, err])
			else:
				push_error("SaveSlotGuard: missing backup for %s" % path)
		_remove_if_exists(_backup_path(path))
	_release_lock()


func _backup_path(path: String) -> String:
	return path + BACKUP_SUFFIX


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _acquire_lock() -> void:
	if _has_lock:
		return
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var started := Time.get_ticks_msec()
	while true:
		var err := DirAccess.make_dir_absolute(LOCK_DIR)
		if err == OK:
			_has_lock = true
			return
		if Time.get_ticks_msec() - started >= LOCK_TIMEOUT_MSEC:
			push_warning("SaveSlotGuard: breaking stale smoke save lock")
			DirAccess.remove_absolute(LOCK_DIR)
			started = Time.get_ticks_msec()
		OS.delay_msec(LOCK_POLL_MSEC)


func _release_lock() -> void:
	if not _has_lock:
		return
	DirAccess.remove_absolute(LOCK_DIR)
	_has_lock = false
