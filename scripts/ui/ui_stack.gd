extends CanvasLayer
## Owns modal visibility and clock pause locks for the gameplay scene.
## Menus can still build their own contents, but opening/closing goes through
## this node so one modal cannot accidentally unpause another.

const PAUSE_MENU_ID := "pause_menu"
const RAGS_UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const ICONS := {
	"resume": "res://assets/ui/icon_resume.png",
	"save": "res://assets/ui/icon_save.png",
	"walk": "res://assets/ui/icon_walk.png",
	"quit": "res://assets/ui/icon_quit.png",
}

var _modals := {}
var _pause_panel: Control = null
var _toast: Label = null


func _ready() -> void:
	layer = 60
	_build_pause_menu()
	_pause_panel.visible = false
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

	var settings := Button.new()
	settings.text = "Settings"
	settings.disabled = true
	settings.tooltip_text = "Settings are part of the Phase 0 UI pass."
	vbox.add_child(settings)

	_add_button(vbox, "Quit to Menu", _quit_to_menu, "quit")

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(_toast)


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


func _save_game() -> void:
	SaveManager.save_game()
	_set_pause_message("Saved.")


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


func _on_node_added(node: Node) -> void:
	if node is Control:
		RAGS_UI_THEME.apply_control(node)
