extends CanvasLayer
## Owns modal visibility and clock pause locks for the gameplay scene.
## Menus can still build their own contents, but opening/closing goes through
## this node so one modal cannot accidentally unpause another.

const PAUSE_MENU_ID := "pause_menu"
const SETTINGS_MODAL_ID := "settings"
const SETTINGS_PATH := "user://settings.cfg"
const RAGS_UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := {
	"resume": "res://assets/ui/icon_resume.png",
	"save": "res://assets/ui/icon_save.png",
	"walk": "res://assets/ui/icon_walk.png",
	"settings": "res://assets/ui/icon_settings.png",
	"quit": "res://assets/ui/icon_quit.png",
}

var _modals := {}
var _pause_panel: Control = null
var _settings_panel: Control = null
var _toast: Label = null
var _master_slider: HSlider = null
var _mute_check: CheckButton = null
var _settings_loaded := false


func _ready() -> void:
	layer = 60
	_load_settings()
	_build_pause_menu()
	_build_settings_menu()
	_pause_panel.visible = false
	_settings_panel.visible = false
	RAGS_UI_THEME.apply_tree(get_parent())
	get_tree().node_added.connect(_on_node_added)


func open_modal(modal_id: String, modal: Node = null, pauses_clock: bool = true) -> void:
	if modal_id == "":
		return
	_modals[modal_id] = {"node": modal, "pauses_clock": pauses_clock}
	if modal != null:
		modal.set("visible", true)
	if pauses_clock:
		GameClock.push_pause_lock(modal_id)


func close_modal(modal_id: String) -> void:
	if modal_id == "":
		return
	var entry: Dictionary = _modals.get(modal_id, {})
	var modal: Node = entry.get("node", null)
	if modal != null:
		modal.set("visible", false)
	if bool(entry.get("pauses_clock", false)):
		GameClock.release_pause_lock(modal_id)
	_modals.erase(modal_id)


func is_modal_open(modal_id: String) -> bool:
	return _modals.has(modal_id)


func close_all() -> void:
	for id in _modals.keys():
		var entry: Dictionary = _modals[id]
		var modal: Node = entry.get("node", null)
		if modal != null:
			modal.set("visible", false)
		if bool(entry.get("pauses_clock", false)):
			GameClock.release_pause_lock(str(id))
	_modals.clear()


func toggle_pause_menu() -> void:
	if is_modal_open(SETTINGS_MODAL_ID):
		_close_settings_menu()
		return
	if is_modal_open(PAUSE_MENU_ID):
		_close_pause_menu()
	else:
		_open_pause_menu()


func _open_pause_menu() -> void:
	_set_pause_message("")
	open_modal(PAUSE_MENU_ID, _pause_panel, true)


func _close_pause_menu() -> void:
	if is_modal_open(PAUSE_MENU_ID):
		close_modal(PAUSE_MENU_ID)
	elif _pause_panel != null:
		_pause_panel.visible = false


func _build_pause_menu() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180, -170)
	panel.custom_minimum_size = Vector2(360, 340)
	_pause_panel.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	_add_button(vbox, "Resume", _close_pause_menu, "resume")
	_add_button(vbox, "Save", _save_game, "save")
	_add_button(vbox, "Walk Away", _walk_away, "walk")
	_add_button(vbox, "Settings", _open_settings_menu, "settings")

	_add_button(vbox, "Quit to Menu", _quit_to_menu, "quit")

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(_toast)


func _build_settings_menu() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -150)
	panel.custom_minimum_size = Vector2(380, 300)
	_settings_panel.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var volume_label := Label.new()
	volume_label.text = "Master volume"
	vbox.add_child(volume_label)

	_master_slider = HSlider.new()
	_master_slider.name = "MasterVolumeSlider"
	_master_slider.min_value = -40.0
	_master_slider.max_value = 0.0
	_master_slider.step = 1.0
	_master_slider.value = AudioServer.get_bus_volume_db(_master_bus())
	_master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_slider.value_changed.connect(_on_master_volume_changed)
	vbox.add_child(_master_slider)

	_mute_check = CheckButton.new()
	_mute_check.name = "MuteAudioCheck"
	_mute_check.text = "Mute audio"
	_mute_check.button_pressed = AudioServer.is_bus_mute(_master_bus())
	_mute_check.toggled.connect(_on_mute_toggled)
	vbox.add_child(_mute_check)

	_add_button(vbox, "Reset Audio", _reset_audio_settings)
	_add_button(vbox, "Back", _close_settings_menu)


func _add_button(parent: Node, text: String, action: Callable, icon_id := "") -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if icon_id != "" and ICONS.has(icon_id):
		var texture: Texture2D = load(ICONS[icon_id])
		if texture:
			button.icon = texture
	button.pressed.connect(action)
	parent.add_child(button)
	RAGS_UI_THEME.apply_control(button)


func _open_settings_menu() -> void:
	open_modal(SETTINGS_MODAL_ID, _settings_panel, true)


func _close_settings_menu() -> void:
	if is_modal_open(SETTINGS_MODAL_ID):
		close_modal(SETTINGS_MODAL_ID)
	elif _settings_panel != null:
		_settings_panel.visible = false


func _save_game() -> void:
	_set_pause_message("Saved." if SaveManager.save_game() else "Save failed.")


func _walk_away() -> void:
	var npc := WorldState.walk_away()
	if npc == null:
		_set_pause_message("No life to walk away from.")
		return
	close_all()
	EventBus.toast.emit("%s's life goes on without you at the wheel." % npc.display_name)
	GameFlow.call_deferred("to_character_creation")


func _quit_to_menu() -> void:
	close_all()
	GameFlow.to_main_menu()


func _set_pause_message(text: String) -> void:
	if _toast != null:
		_toast.text = text


func _load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	var volume := AudioServer.get_bus_volume_db(_master_bus())
	var muted := false
	if err == OK:
		volume = float(config.get_value("audio", "master_volume_db", volume))
		muted = bool(config.get_value("audio", "muted", muted))
	_apply_audio_settings(volume, muted, false)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume_db", AudioServer.get_bus_volume_db(_master_bus()))
	config.set_value("audio", "muted", AudioServer.is_bus_mute(_master_bus()))
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("UIStack: could not save settings (%d)" % err)


func _on_master_volume_changed(value: float) -> void:
	_apply_audio_settings(value, AudioServer.is_bus_mute(_master_bus()))


func _on_mute_toggled(enabled: bool) -> void:
	_apply_audio_settings(AudioServer.get_bus_volume_db(_master_bus()), enabled)


func _reset_audio_settings() -> void:
	_apply_audio_settings(0.0, false)
	if _master_slider != null:
		_master_slider.value = 0.0
	if _mute_check != null:
		_mute_check.button_pressed = false


func _apply_audio_settings(volume_db: float, muted: bool, persist := true) -> void:
	var master := _master_bus()
	AudioServer.set_bus_volume_db(master, clampf(volume_db, -40.0, 0.0))
	AudioServer.set_bus_mute(master, muted)
	if persist:
		_save_settings()


func _master_bus() -> int:
	return max(0, AudioServer.get_bus_index("Master"))


func _on_node_added(node: Node) -> void:
	if node is Control:
		RAGS_UI_THEME.apply_control(node)
