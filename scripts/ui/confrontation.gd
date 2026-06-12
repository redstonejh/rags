extends CanvasLayer
## Confrontation UI: renders the universal standoff. Listens for
## confrontation_started payloads ({kind, npc_id, text}), shows the options
## from Confrontation.options() with their perceived odds, applies the pick,
## and chains follow-ups (win a fight -> mercy/rob/kill). Clock pauses.

var _panel: PanelContainer
var _text_label: Label
var _options_box: VBoxContainer
var _kind := ""
var _npc: NPCRecord = null
const MODAL_ID := "confrontation"


func _ready() -> void:
	layer = 25
	visible = false
	_build_ui()
	EventBus.confrontation_started.connect(_open)


func _build_ui() -> void:
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.position = Vector2(-260, -140)
	blocker.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var header := Label.new()
	header.text = "EVERYTHING STOPS"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.85, 0.4, 0.3))
	vbox.add_child(header)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(500, 0)
	vbox.add_child(_text_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_options_box)


func _open(payload: Dictionary) -> void:
	_kind = str(payload.get("kind", ""))
	_npc = WorldState.npcs.get(str(payload.get("npc_id", "")))
	_text_label.text = str(payload.get("text", ""))
	_render_options()
	if not visible:
		var stack := _ui_stack()
		if stack != null:
			stack.call("open_modal", MODAL_ID, self, true)
		else:
			visible = true
			GameClock.push_pause_lock(MODAL_ID)


func _render_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()
	for opt in Confrontation.options(_kind, WorldState.player_sheet, _npc):
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s   (%s)" % [opt.label, opt.get("sub", "")]
		btn.pressed.connect(_choose.bind(str(opt.id)))
		_options_box.add_child(btn)


func _choose(choice: String) -> void:
	var result := Confrontation.resolve(_kind, choice, WorldState.player_sheet, _npc)
	_text_label.text = str(result.text)
	var follow: Dictionary = result.get("follow_up", {})
	if not follow.is_empty():
		_open(follow)
		_text_label.text = "%s\n\n%s" % [result.text, str(follow.get("text", ""))]
		return
	if result.done:
		for child in _options_box.get_children():
			child.queue_free()
		var leave := Button.new()
		leave.text = "Walk away"
		leave.pressed.connect(_close)
		_options_box.add_child(leave)
	else:
		_render_options() # the option fizzled (can't afford bail); pick again


func _close() -> void:
	var stack := _ui_stack()
	if stack != null:
		stack.call("close_modal", MODAL_ID)
	else:
		GameClock.release_pause_lock(MODAL_ID)
		visible = false
	_npc = null


func _ui_stack() -> Node:
	return get_parent().get_node_or_null("UIStack") if get_parent() != null else null
