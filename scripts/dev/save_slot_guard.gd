class_name SaveSlotGuard
extends RefCounted
## Temporarily preserves the ironman save slot while smoke tests write to it.

const SAVE_FILES := [
	SaveManager.SAVE_PATH,
	SaveManager.SAVE_PATH + ".bak",
]
const BACKUP_SUFFIX := ".smoke_backup"

var _had_file := {}


func backup() -> void:
	for path in SAVE_FILES:
		_had_file[path] = FileAccess.file_exists(path)
		_remove_if_exists(_backup_path(path))
		if bool(_had_file[path]):
			DirAccess.copy_absolute(path, _backup_path(path))


func restore() -> void:
	for path in SAVE_FILES:
		_remove_if_exists(path)
		if bool(_had_file.get(path, false)):
			DirAccess.copy_absolute(_backup_path(path), path)
		_remove_if_exists(_backup_path(path))


func _backup_path(path: String) -> String:
	return path + BACKUP_SUFFIX


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
