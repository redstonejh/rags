extends CanvasLayer
## Shop UI: opens when any ShopCounter emits shop_opened. Infinite stock in
## M3; prices come straight off the ItemDefs. Cash is cash — the clerk takes
## the dirty kind too, this is not that kind of store.

var _panel: PanelContainer
var _rows_box: VBoxContainer
var _cash_label: Label


func _ready() -> void:
	layer = 11
	visible = false
	_build_ui()
	EventBus.shop_opened.connect(_open)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		visible = false
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(480, 420)
	_panel.position = Vector2(-240, -210)
	blocker.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "🛒  QUIKSTOP — \"Open Late. Regret Later.\""
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	_cash_label = Label.new()
	_cash_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_cash_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows_box)


func _open(stock: Array) -> void:
	for child in _rows_box.get_children():
		child.queue_free()
	for item_id in stock:
		var item := ContentDB.get_item(item_id)
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_rows_box.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.text = "%s — $%.2f\n%s" % [item.display_name, item.value_cents / 100.0, item.description]
		info.add_theme_font_size_override("font_size", 12)
		row.add_child(info)
		var btn := Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(70, 0)
		btn.pressed.connect(_buy.bind(item))
		row.add_child(btn)
	_update_cash()
	visible = true


func _buy(item: ItemDef) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet.cash_cents + sheet.dirty_cents < item.value_cents:
		EventBus.toast.emit("The register makes a sad noise. You can't afford that.")
		return
	# Clean cash first; the street kind covers the rest. The clerk doesn't care.
	var from_clean: int = mini(sheet.cash_cents, item.value_cents)
	if from_clean > 0:
		sheet.add_cash(-from_clean)
	sheet.dirty_cents -= item.value_cents - from_clean
	sheet.inventory.append(item.id)
	EventBus.toast.emit("Bought %s. (I to use it.)" % item.display_name)
	_update_cash()


func _update_cash() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var text := "Cash: $%.2f" % (sheet.cash_cents / 100.0)
	if sheet.dirty_cents > 0:
		text += "   (+$%.2f of the other kind)" % (sheet.dirty_cents / 100.0)
	_cash_label.text = text
