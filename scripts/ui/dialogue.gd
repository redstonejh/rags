extends CanvasLayer
## Dialogue UI: the stat-gated intent menu with VISIBLE (perceived) odds,
## Fallout-style. The odds you see came out of your character's head, not
## the simulation — see Perception. Clock pauses while you talk.

var _panel: PanelContainer
var _name_label: Label
var _rel_label: Label
var _read_label: Label
var _reality_label: Label
var _result_label: Label
var _actions_box: GridContainer
var _portrait: TextureRect
var _npc: NPCRecord = null
var _revealed_action: String = ""
var _revealed_perceived: float = -1.0
var _revealed_actual: float = -1.0
const MODAL_ID := "dialogue"
const PORTRAIT_DIR := "res://assets/portraits/"


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
	_panel.custom_minimum_size = Vector2(680, 0)
	_panel.position = Vector2(-340, -340)
	blocker.add_child(_panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_panel.add_child(root)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = 1
	root.add_child(_portrait)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

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

	_reality_label = Label.new()
	_reality_label.name = "RealityCheckLabel"
	_reality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reality_label.visible = false
	_reality_label.add_theme_font_size_override("font_size", 14)
	_reality_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
	vbox.add_child(_reality_label)

	_result_label = Label.new()
	_result_label.name = "DialogueResult"
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(540, 0)
	vbox.add_child(_result_label)

	_actions_box = GridContainer.new()
	_actions_box.columns = 2
	_actions_box.add_theme_constant_override("h_separation", 6)
	_actions_box.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_actions_box)


func _open(npc_id: String) -> void:
	_npc = WorldState.npcs.get(npc_id)
	if _npc == null:
		return
	_result_label.text = ""
	_clear_reality_check()
	_set_portrait(_npc)
	_read_label.text = "( %s )" % Perception.read_line(WorldState.player_sheet, _npc)
	_refresh()
	var stack := _ui_stack()
	if stack != null:
		stack.call("open_modal", MODAL_ID, self, true)
	else:
		visible = true
		GameClock.push_pause_lock(MODAL_ID)


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
		btn.name = "Action_%s" % action_id
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(260, 0)
		if def.get("roll", false):
			var shown := Social.perceived_chance(sheet, _npc, action_id)
			btn.text = "%s  —  %d%%" % [def.label, roundi(shown * 100)]
		else:
			btn.text = str(def.get("label", action_id))
		if action_id == _revealed_action:
			btn.text = "%s  -  %d%% -> %d%%" % [
				def.get("label", action_id),
				roundi(_revealed_perceived * 100),
				roundi(_revealed_actual * 100)]
			btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		btn.pressed.connect(_do_action.bind(action_id))
		_actions_box.add_child(btn)


func _set_portrait(npc: NPCRecord) -> void:
	var texture: Texture2D = load(PORTRAIT_DIR + npc.archetype_id + ".png")
	if texture == null:
		_portrait.texture = null
		_portrait.visible = false
		return
	_portrait.texture = texture
	_portrait.visible = true


func _do_action(action_id: String) -> void:
	_do_action_with_roll(action_id)
	return
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


func _do_action_with_roll(action_id: String, forced_roll := -1.0) -> void:
	if _npc == null:
		return
	var result := Social.interact(WorldState.player_sheet, _npc, action_id, forced_roll)
	if result.reality_check:
		_revealed_action = action_id
		_revealed_perceived = float(result.perceived)
		_revealed_actual = float(result.actual)
		_reality_label.text = "REALITY CHECK: %d%% -> %d%%\nThe read collapses in public. Heads turn. This story can travel." % [
			roundi(result.perceived * 100), roundi(result.actual * 100)]
		_reality_label.visible = true
		_result_label.text = result.text
		_result_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	else:
		_clear_reality_check()
		_result_label.text = result.text
		_result_label.add_theme_color_override("font_color",
				Color(0.8, 0.9, 0.75) if result.success else Color(0.8, 0.7, 0.6))
	_refresh()


func _clear_reality_check() -> void:
	_revealed_action = ""
	_revealed_perceived = -1.0
	_revealed_actual = -1.0
	if _reality_label != null:
		_reality_label.text = ""
		_reality_label.visible = false


func _rel_text(value: float) -> String:
	var word := "strangers"
	if value >= 70.0: word = "close"
	elif value >= 40.0: word = "friends"
	elif value >= 15.0: word = "friendly"
	elif value <= -40.0: word = "enemies"
	elif value <= -15.0: word = "sour"
	return "%s (%d)" % [word, roundi(value)]
