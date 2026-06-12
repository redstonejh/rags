extends CanvasLayer
## Shop UI: opens when any ShopCounter emits shop_opened. Infinite stock in
## M3; prices come straight off the ItemDefs. Cash is cash — the clerk takes
## the dirty kind too, this is not that kind of store.

var _panel: PanelContainer
var _rows_box: VBoxContainer
var _cash_label: Label
const MODAL_ID := "shop"


func _ready() -> void:
	layer = 11
	visible = false
	_build_ui()
	EventBus.shop_opened.connect(_open)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		_close()
		get_viewport().set_input_as_handled()


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
	close.pressed.connect(_close)
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
		_rows_box.remove_child(child)
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
		btn.name = "Buy_%s" % item.id
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(70, 0)
		btn.pressed.connect(_buy.bind(item))
		row.add_child(btn)
		var pocket := Button.new()
		pocket.name = "Pocket_%s" % item.id
		pocket.text = "Pocket"
		pocket.tooltip_text = _shoplift_risk_text()
		pocket.custom_minimum_size = Vector2(70, 0)
		pocket.pressed.connect(_shoplift.bind(item))
		row.add_child(pocket)
	var rob := Button.new()
	rob.text = "🔫  Rob the register"
	rob.pressed.connect(_rob_register)
	_rows_box.add_child(rob)
	_update_cash()
	var stack := _ui_stack()
	if stack != null:
		stack.call("open_modal", MODAL_ID, self, true)
	else:
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
	var from_dirty := item.value_cents - from_clean
	if from_dirty > 0:
		sheet.add_dirty_cash(-from_dirty)
	sheet.inventory.append(item.id)
	EventBus.path_updated.emit()
	EventBus.toast.emit("Bought %s. (I to use it.)" % item.display_name)
	_update_cash()


## Catch chance starts from DESIGN.md's 20% baseline, then sightlines do the rest.
func _shoplift(item: ItemDef) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var catch_chance := CrimeSystem.shoplift_catch_chance(sheet, WorldState.player_location_id)
	if CrimeSystem.roll_chance(catch_chance):
		var case := CrimeSystem.commit("shoplift", WorldState.player_location_id)
		if case.status != CrimeCase.UNREPORTED:
			EventBus.toast.emit("\"HEY!\" %s. The %s stays." % [
					CrimeSystem.shoplift_attention_text(WorldState.player_location_id).capitalize(),
					item.display_name])
		else:
			EventBus.toast.emit("The %s catches on the rack. No one reports it, but your pulse does." %
					item.display_name)
	else:
		sheet.inventory.append(item.id)
		sheet.add_skill_xp("stealth", 1.0)
		EventBus.path_updated.emit()
		EventBus.toast.emit("The %s was always yours, officer." % item.display_name)


func _shoplift_risk_text() -> String:
	var sheet: CharacterSheet = WorldState.player_sheet
	var chance := CrimeSystem.shoplift_catch_chance(sheet, WorldState.player_location_id)
	var attention := CrimeSystem.shoplift_attention_text(WorldState.player_location_id)
	return "Five-finger discount. Catch risk: %d%%; %s." % [
		roundi(chance * 100.0), attention]


## Always witnesses. ALWAYS. That's what the 'armed' part buys you.
func _rob_register() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var loot := CrimeSystem.random_int(20000, 60000)
	sheet.add_dirty_cash(loot)
	CrimeSystem.commit_register_robbery(WorldState.player_location_id)
	EventBus.toast.emit("$%.2f in a paper bag. Everyone in the store memorized your face." % (loot / 100.0))
	_close()


func _update_cash() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var text := "Cash: $%.2f" % (sheet.cash_cents / 100.0)
	if sheet.dirty_cents > 0:
		text += "   (+$%.2f of the other kind)" % (sheet.dirty_cents / 100.0)
	_cash_label.text = text
