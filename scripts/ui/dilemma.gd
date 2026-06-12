extends CanvasLayer
## Post-shift dilemma popup. ShiftSystem rolls and emits the event; this
## layer presents the choices and applies the one you pick. Nothing happens
## until you choose — the moment waits (clock pauses for the read).

var _panel: PanelContainer
var _text_label: Label
var _choices_box: VBoxContainer
var _was_paused := false


func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	EventBus.shift_dilemma.connect(_show_dilemma)


func _build_ui() -> void:
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.position = Vector2(-230, -120)
	blocker.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var header := Label.new()
	header.text = "MEANWHILE, AT WORK"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	vbox.add_child(header)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(440, 0)
	vbox.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_choices_box)


func _show_dilemma(dilemma: Dictionary) -> void:
	_text_label.text = str(dilemma.get("text", ""))
	for child in _choices_box.get_children():
		child.queue_free()
	var sheet: CharacterSheet = WorldState.player_sheet
	for choice in dilemma.get("choices", []):
		var btn := Button.new()
		var cash := int(choice.get("cash", 0))
		var suffix := ""
		if cash > 0:
			suffix = "  (+$%.2f)" % (cash / 100.0)
		elif cash < 0:
			suffix = "  (-$%.2f)" % (-cash / 100.0)
		btn.text = str(choice.get("label", "...")) + suffix
		btn.disabled = cash < 0 and sheet.cash_cents < -cash
		btn.pressed.connect(_choose.bind(choice))
		_choices_box.add_child(btn)
	_was_paused = GameClock.paused
	GameClock.paused = true
	visible = true


func _choose(choice: Dictionary) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var cash := int(choice.get("cash", 0))
	if cash != 0:
		sheet.add_cash(cash)
	var need_deltas: Dictionary = choice.get("needs", {})
	for need_id in need_deltas:
		sheet.needs.change(need_id, float(need_deltas[need_id]))
	EventBus.toast.emit(str(choice.get("result", "")))
	GameClock.paused = _was_paused
	visible = false
