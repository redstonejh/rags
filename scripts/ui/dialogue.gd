extends CanvasLayer
## Dialogue UI: the stat-gated intent menu with visible perceived odds.
## The odds come from the character's read, while outcomes resolve against
## hidden truth in Social/Perception. Clock pauses while you talk.

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
var _date_scene_action: String = ""

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
	close.text = "X"
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
	_date_scene_action = ""
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
	_name_label.text = _npc.display_name + ("  <3" if _npc.flags.get("dating_player", false) else "")
	_rel_label.text = _rel_text(_npc.rel("player"))
	for child in _actions_box.get_children():
		child.queue_free()

	if _date_scene_action != "":
		_refresh_date_scene()
		return

	var sheet: CharacterSheet = WorldState.player_sheet
	for action_id in Social.available_actions(sheet, _npc):
		var def: Dictionary = Social.ACTIONS.get(action_id, {
			"label": "Spend time together",
			"roll": false,
		})
		var btn := Button.new()
		btn.name = "Action_%s" % action_id
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(260, 0)
		if def.get("roll", false):
			var shown := Social.perceived_chance(sheet, _npc, action_id)
			btn.text = "%s  -  %d%%" % [def.label, roundi(shown * 100)]
		else:
			btn.text = str(def.get("label", action_id))
		if action_id == _revealed_action:
			btn.text = "%s  -  %d%% -> %d%%" % [
				def.get("label", action_id),
				roundi(_revealed_perceived * 100),
				roundi(_revealed_actual * 100),
			]
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
	if Social.is_date_scene(action_id):
		_open_date_scene(action_id)
		return
	_do_action_with_roll(action_id)


func _do_action_with_roll(action_id: String, forced_roll := -1.0) -> void:
	if _npc == null:
		return
	if _is_date_choice(action_id):
		_date_scene_action = ""
	var result := Social.interact(WorldState.player_sheet, _npc, action_id, forced_roll)
	if result.reality_check:
		_revealed_action = action_id
		_revealed_perceived = float(result.perceived)
		_revealed_actual = float(result.actual)
		_reality_label.text = "REALITY CHECK: %d%% -> %d%%\nThe read collapses in public. Heads turn. This story can travel." % [
			roundi(result.perceived * 100),
			roundi(result.actual * 100),
		]
		_reality_label.visible = true
		_result_label.text = result.text
		_result_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	else:
		_clear_reality_check()
		_result_label.text = result.text
		_result_label.add_theme_color_override("font_color",
				Color(0.8, 0.9, 0.75) if result.success else Color(0.8, 0.7, 0.6))
	_refresh()


func _open_date_scene(action_id: String) -> void:
	var scene := Social.date_scene(action_id)
	if scene.is_empty():
		return
	_clear_reality_check()
	_date_scene_action = action_id
	_result_label.text = "%s\n%s" % [str(scene.get("title", "")), str(scene.get("prompt", ""))]
	_result_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.75))
	_refresh()


func _refresh_date_scene() -> void:
	var scene := Social.date_scene(_date_scene_action)
	if scene.is_empty():
		_date_scene_action = ""
		return
	for choice in scene.get("choices", []):
		var choice_dict: Dictionary = choice
		var btn := Button.new()
		btn.name = "DateChoice_%s" % str(choice_dict.get("id", ""))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(260, 0)
		btn.text = str(choice_dict.get("label", "Spend time"))
		btn.pressed.connect(_do_action_with_roll.bind(str(choice_dict.get("id", ""))))
		_actions_box.add_child(btn)
	var back := Button.new()
	back.name = "DateChoice_Back"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.custom_minimum_size = Vector2(260, 0)
	back.text = "Back"
	back.pressed.connect(func() -> void:
		_date_scene_action = ""
		_result_label.text = ""
		_refresh())
	_actions_box.add_child(back)


func _is_date_choice(action_id: String) -> bool:
	return action_id.begins_with("date_mels_") or action_id.begins_with("date_anchor_")


func _clear_reality_check() -> void:
	_revealed_action = ""
	_revealed_perceived = -1.0
	_revealed_actual = -1.0
	if _reality_label != null:
		_reality_label.text = ""
		_reality_label.visible = false


func _rel_text(value: float) -> String:
	var word := "strangers"
	if value >= 70.0:
		word = "close"
	elif value >= 40.0:
		word = "friends"
	elif value >= 15.0:
		word = "friendly"
	elif value <= -40.0:
		word = "enemies"
	elif value <= -15.0:
		word = "sour"
	return "%s (%d)" % [word, roundi(value)]
