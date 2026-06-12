extends CanvasLayer
## Dialogue UI: the stat-gated intent menu with VISIBLE (perceived) odds,
## Fallout-style. The odds you see came out of your character's head, not
## the simulation — see Perception. Clock pauses while you talk.

var _panel: PanelContainer
var _name_label: Label
var _rel_label: Label
var _read_label: Label
var _result_label: Label
var _actions_box: VBoxContainer
var _npc: NPCRecord = null
var _was_paused := false


func _ready() -> void:
	layer = 15
	visible = false
	_build_ui()
	EventBus.dialogue_requested.connect(_open)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.position = Vector2(-280, -340)
	blocker.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	_rel_label = Label.new()
	_rel_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_rel_label)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(_close)
	header.add_child(close)

	_read_label = Label.new()
	_read_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_read_label.add_theme_font_size_override("font_size", 12)
	_read_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.55))
	vbox.add_child(_read_label)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(540, 0)
	vbox.add_child(_result_label)

	_actions_box = VBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_actions_box)


func _open(npc_id: String) -> void:
	_npc = WorldState.npcs.get(npc_id)
	if _npc == null:
		return
	_was_paused = GameClock.paused
	GameClock.paused = true
	_result_label.text = ""
	_read_label.text = "( %s )" % Perception.read_line(WorldState.player_sheet, _npc)
	_refresh()
	visible = true


func _close() -> void:
	GameClock.paused = _was_paused
	visible = false
	_npc = null


func _refresh() -> void:
	if _npc == null:
		return
	_name_label.text = _npc.display_name + ("  ♥" if _npc.flags.get("dating_player", false) else "")
	_rel_label.text = _rel_text(_npc.rel("player"))
	for child in _actions_box.get_children():
		child.queue_free()
	var sheet: CharacterSheet = WorldState.player_sheet
	for action_id in Social.available_actions(sheet, _npc):
		var def: Dictionary = Social.ACTIONS.get(action_id, {"label": "Spend time together", "roll": false})
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if def.get("roll", false):
			var shown := Social.perceived_chance(sheet, _npc, action_id)
			btn.text = "%s  —  %d%%" % [def.label, roundi(shown * 100)]
		else:
			btn.text = str(def.get("label", action_id))
		btn.pressed.connect(_do_action.bind(action_id))
		_actions_box.add_child(btn)


func _do_action(action_id: String) -> void:
	if _npc == null:
		return
	var result := Social.interact(WorldState.player_sheet, _npc, action_id)
	if result.reality_check:
		# The on-screen odds visibly collapse: what you believed, then the truth.
		_result_label.text = "[ %d%% → %d%% ]  %s" % [
			roundi(result.perceived * 100), roundi(result.actual * 100), result.text]
		_result_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	else:
		_result_label.text = result.text
		_result_label.add_theme_color_override("font_color",
				Color(0.8, 0.9, 0.75) if result.success else Color(0.8, 0.7, 0.6))
	_refresh()


func _rel_text(value: float) -> String:
	var word := "strangers"
	if value >= 70.0: word = "close"
	elif value >= 40.0: word = "friends"
	elif value >= 15.0: word = "friendly"
	elif value <= -40.0: word = "enemies"
	elif value <= -15.0: word = "sour"
	return "%s (%d)" % [word, roundi(value)]
