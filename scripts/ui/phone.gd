extends CanvasLayer
## The phone — the diegetic menu (Tab opens it). M3 apps: Jobs (the job
## board), Bank (needs ID), Mickey (the other bank), Paths (your Journal).
## All widgets are built in code; the .tscn is just this CanvasLayer.

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MICKEY_BORROW_OPTIONS := [10000, 50000]
const BANK_STEP_CENTS := 5000

var _tabs: TabContainer
var _jobs_box: VBoxContainer
var _bank_box: VBoxContainer
var _mickey_box: VBoxContainer
var _paths_box: VBoxContainer


func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()
	EventBus.path_updated.connect(func() -> void:
		if visible:
			_refresh_paths())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone"):
		visible = not visible
		if visible:
			_refresh_all()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 500)
	panel.position = Vector2(-310, -250)
	blocker.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "📱  PHONE"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕  [Tab]"
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)

	_jobs_box = _make_tab("Jobs")
	_bank_box = _make_tab("Bank")
	_mickey_box = _make_tab("Mickey")
	_paths_box = _make_tab("Paths")


func _make_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _refresh_all() -> void:
	_refresh_jobs()
	_refresh_bank()
	_refresh_mickey()
	_refresh_paths()


func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()


# ------------------------------------------------------------------- jobs

func _refresh_jobs() -> void:
	_clear(_jobs_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	var intro := Label.new()
	intro.text = "RUST HARBOR JOB BOARD — \"Now hiring. Always hiring. Wonder why.\""
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_jobs_box.add_child(intro)
	for job in ContentDB.all_jobs():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_jobs_box.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.text = "%s — $%.0f/shift\n%s %d:00–%d:00 at %s%s" % [
			job.display_name, job.wage_cents_per_shift / 100.0,
			_days_string(job.work_days), job.shift_start_hour,
			(job.shift_start_hour + job.shift_len_hours) % 24,
			Locations.display_name(job.workplace_id),
			"" if job.blurb == "" else "\n\"%s\"" % job.blurb]
		info.add_theme_font_size_override("font_size", 12)
		row.add_child(info)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 0)
		if sheet.job_id == job.id:
			btn.text = "Current job"
			btn.disabled = true
		else:
			var blocker := _job_blocker(sheet, job)
			if blocker == "":
				btn.text = "Apply"
				btn.pressed.connect(_apply_for.bind(job))
			else:
				btn.text = blocker
				btn.disabled = true
		row.add_child(btn)


func _job_blocker(sheet: CharacterSheet, job: JobDef) -> String:
	if job.requires_id and not sheet.flags.get("has_id", false):
		return "needs ID"
	for skill in job.skill_reqs:
		if sheet.skill_level(skill) < int(job.skill_reqs[skill]):
			return "needs %s %d" % [skill, int(job.skill_reqs[skill])]
	return ""


func _apply_for(job: JobDef) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	sheet.job_id = job.id
	sheet.shifts_worked = 0
	EventBus.player_job_changed.emit(job.id)
	EventBus.toast.emit("Hired: %s. Be at %s by %d:00. Congratulations, or something." % [
		job.display_name, Locations.display_name(job.workplace_id), job.shift_start_hour])
	_refresh_jobs()


func _days_string(days: Array) -> String:
	var names: Array = []
	for d in days:
		names.append(DAY_NAMES[int(d) % 7])
	return "/".join(names)


# ------------------------------------------------------------------- bank

func _refresh_bank() -> void:
	_clear(_bank_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	if not sheet.flags.get("has_id", false):
		var denied := Label.new()
		denied.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		denied.text = "FIRST HARBOR SAVINGS & LOAN\n\n\"We'd love to help. We require ID.\"\n\nYou, officially, are not anyone. (See: Paths.)"
		_bank_box.add_child(denied)
		return
	var balance := Label.new()
	balance.text = "Balance: $%.2f      Cash on hand: $%.2f" % [
		sheet.bank_cents / 100.0, sheet.cash_cents / 100.0]
	balance.add_theme_font_size_override("font_size", 14)
	_bank_box.add_child(balance)
	var note := Label.new()
	note.text = "Clean cash only. The teller can smell the other kind."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_bank_box.add_child(note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bank_box.add_child(row)
	_bank_button(row, "Deposit $50", func() -> void: _bank_move(mini(BANK_STEP_CENTS, sheet.cash_cents)))
	_bank_button(row, "Deposit all", func() -> void: _bank_move(sheet.cash_cents))
	_bank_button(row, "Withdraw $50", func() -> void: _bank_move(-mini(BANK_STEP_CENTS, sheet.bank_cents)))
	_bank_button(row, "Withdraw all", func() -> void: _bank_move(-sheet.bank_cents))


func _bank_button(parent: Node, label: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(action)
	parent.add_child(btn)


## Positive = pocket -> bank, negative = bank -> pocket.
func _bank_move(amount_cents: int) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if amount_cents == 0:
		return
	if amount_cents > 0 and sheet.cash_cents >= amount_cents:
		sheet.add_cash(-amount_cents)
		sheet.bank_cents += amount_cents
	elif amount_cents < 0 and sheet.bank_cents >= -amount_cents:
		sheet.bank_cents += amount_cents
		sheet.add_cash(-amount_cents)
	_refresh_bank()


# ------------------------------------------------------------------- mickey

func _refresh_mickey() -> void:
	_clear(_mickey_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	var debt := Label.new()
	debt.add_theme_font_size_override("font_size", 14)
	debt.text = "You owe Big Mickey: $%.2f" % (sheet.mickey_debt_cents / 100.0) \
			if sheet.mickey_debt_cents > 0 else "You owe Big Mickey: nothing. Keep it that way."
	_mickey_box.add_child(debt)
	var terms := Label.new()
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms.text = "Terms: 20% weekly, compounding Mondays. No forms, no ID, no questions.\nCollections policy: a reminder, then a beating, then your stuff, then your kneecaps."
	terms.add_theme_font_size_override("font_size", 11)
	terms.add_theme_color_override("font_color", Color(0.7, 0.55, 0.5))
	_mickey_box.add_child(terms)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_mickey_box.add_child(row)
	for amount in MICKEY_BORROW_OPTIONS:
		var btn := Button.new()
		btn.text = "Borrow $%d" % (amount / 100)
		btn.pressed.connect(_borrow.bind(amount))
		row.add_child(btn)
	if sheet.mickey_debt_cents > 0:
		var repay := Button.new()
		var payable: int = mini(sheet.cash_cents, sheet.mickey_debt_cents)
		repay.text = "Repay $%.2f" % (payable / 100.0)
		repay.disabled = payable <= 0
		repay.pressed.connect(_repay)
		row.add_child(repay)


func _borrow(amount_cents: int) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	sheet.add_cash(amount_cents)
	sheet.mickey_debt_cents += amount_cents
	EventBus.toast.emit("Mickey peels off $%d like it's nothing. For him it is. For you it's 20%% a week." % (amount_cents / 100))
	_refresh_mickey()


func _repay() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var payment: int = mini(sheet.cash_cents, sheet.mickey_debt_cents)
	if payment <= 0:
		return
	sheet.add_cash(-payment)
	sheet.mickey_debt_cents -= payment
	EventBus.toast.emit("Paid Mickey $%.2f. %s" % [payment / 100.0,
			"The ledger closes. He looks almost disappointed." if sheet.mickey_debt_cents == 0
			else "The ledger remembers the rest."])
	_refresh_mickey()


# ------------------------------------------------------------------- paths

func _refresh_paths() -> void:
	_clear(_paths_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	var paths := LifePaths.evaluate(sheet)
	if paths.is_empty():
		var none := Label.new()
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = "No active paths. Your bureaucratic affairs are, troublingly, in order."
		_paths_box.add_child(none)
		return
	for path in paths:
		var name_label := Label.new()
		name_label.text = path.name.to_upper()
		name_label.add_theme_font_size_override("font_size", 14)
		_paths_box.add_child(name_label)
		for step in path.steps:
			var step_label := Label.new()
			var mark := "✔" if step.done else ("→" if step.current else "○")
			step_label.text = "   %s  %s" % [mark, step.label]
			step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if step.done:
				step_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
			elif step.current:
				step_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
			else:
				step_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
			_paths_box.add_child(step_label)
