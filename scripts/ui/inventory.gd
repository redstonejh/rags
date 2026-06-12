extends CanvasLayer
## Inventory UI (I toggles). Stacks duplicates, Use consumes one — need
## effects apply and calories go on the daily ledger.

var _rows_box: VBoxContainer
const MODAL_ID := "inventory"


func _ready() -> void:
	layer = 12
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_refresh()
	var stack := _ui_stack()
	if stack != null:
		stack.call("open_modal", MODAL_ID, self, true)
	else:
		visible = true


func _close() -> void:
	var stack := _ui_stack()
	if stack != null:
		stack.call("close_modal", MODAL_ID)
	else:
		visible = false


func _ui_stack() -> Node:
	return get_parent().get_node_or_null("UIStack") if get_parent() != null else null


func _build_ui() -> void:
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(440, 380)
	panel.position = Vector2(-220, -190)
	blocker.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "🎒  EVERYTHING YOU OWN"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕  [I]"
	close.pressed.connect(_close)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows_box)


func _refresh() -> void:
	for child in _rows_box.get_children():
		child.queue_free()
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet.inventory.is_empty():
		var empty := Label.new()
		empty.text = "It fits in one breath: nothing."
		_rows_box.add_child(empty)
		return
	var counts := {}
	for item_id in sheet.inventory:
		counts[item_id] = counts.get(item_id, 0) + 1
	for item_id in counts:
		var item := ContentDB.get_item(item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_rows_box.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var item_name: String = item.display_name if item else item_id
		var desc: String = item.description if item else ""
		info.text = "%dx %s\n%s" % [counts[item_id], item_name, desc]
		info.add_theme_font_size_override("font_size", 12)
		row.add_child(info)
		if item and "consumable" in item.tags:
			var btn := Button.new()
			btn.text = "Use"
			btn.custom_minimum_size = Vector2(70, 0)
			btn.pressed.connect(_use.bind(item_id))
			row.add_child(btn)
		elif item and "clothing" in item.tags:
			var worn: bool = str(sheet.flags.get("outfit", "")) == item_id
			var wear := Button.new()
			wear.text = "Worn ✓" if worn else "Wear"
			wear.disabled = worn
			wear.custom_minimum_size = Vector2(70, 0)
			wear.pressed.connect(_wear.bind(item_id))
			row.add_child(wear)


func _use(item_id: String) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		return
	var needs_before := sheet.needs.values.duplicate()
	var calories_before := int(sheet.flags.get("calories_today", 0))
	if sheet.consume_item(item_id):
		var item := ContentDB.get_item(item_id)
		EventBus.survival_feedback.emit("eat", "Eat",
				_use_detail(item, item_id, needs_before, calories_before))
		EventBus.toast.emit(_use_feedback(item, item_id, needs_before, calories_before))
	_refresh()


func _use_detail(item: ItemDef, fallback_id: String, needs_before: Dictionary,
		calories_before: int) -> String:
	var item_name := item.display_name if item else fallback_id
	var parts := _use_effect_parts(needs_before, calories_before)
	return "%s. %s" % [item_name, ", ".join(parts)] if not parts.is_empty() else item_name


func _use_feedback(item: ItemDef, fallback_id: String, needs_before: Dictionary,
		calories_before: int) -> String:
	var item_name := item.display_name if item else fallback_id
	var parts := _use_effect_parts(needs_before, calories_before)
	return "Used %s. %s" % [item_name, ", ".join(parts)] if not parts.is_empty() \
			else "Used %s." % item_name


func _use_effect_parts(needs_before: Dictionary, calories_before: int) -> Array[String]:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		return []
	var parts: Array[String] = []
	for need_id in sheet.needs.values:
		var before := float(needs_before.get(need_id, sheet.needs.get_value(need_id)))
		var after := sheet.needs.get_value(need_id)
		var delta := after - before
		if absf(delta) >= 0.5:
			parts.append("%s %+d" % [need_id.capitalize(), int(round(delta))])
	var calories_after := int(sheet.flags.get("calories_today", 0))
	var calories_delta := calories_after - calories_before
	if calories_delta > 0:
		parts.append("%d kcal logged" % calories_delta)
	return parts


func _wear(item_id: String) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	sheet.flags["outfit"] = item_id
	var item := ContentDB.get_item(item_id)
	EventBus.toast.emit("Wearing the %s now. Status tier %d. The town notices clothes." % [
			item.display_name if item else item_id, sheet.outfit_tier()])
	_refresh()
