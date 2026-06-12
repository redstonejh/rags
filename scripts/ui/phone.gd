extends CanvasLayer
## The phone — the diegetic menu (Tab opens it). M3 apps: Jobs (the job
## board), Bank (needs ID), Mickey (the other bank), Paths (your Journal).
## All widgets are built in code; the .tscn is just this CanvasLayer.

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MICKEY_BORROW_OPTIONS := [10000, 50000]
const BANK_STEP_CENTS := 5000
const MODAL_ID := "phone"

var _tabs: TabContainer
var _jobs_box: VBoxContainer
var _home_box: VBoxContainer
var _bank_box: VBoxContainer
var _mickey_box: VBoxContainer
var _health_box: VBoxContainer
var _paths_box: VBoxContainer
var _town_box: VBoxContainer


func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()
	EventBus.path_updated.connect(func() -> void:
		if visible:
			_refresh_paths())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone"):
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_refresh_all()
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
	close.pressed.connect(_close)
	header.add_child(close)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)

	_jobs_box = _make_tab("Jobs")
	_home_box = _make_tab("Home")
	_bank_box = _make_tab("Bank")
	_mickey_box = _make_tab("Mickey")
	_health_box = _make_tab("Health")
	_paths_box = _make_tab("Paths")
	_town_box = _make_tab("Town")


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
	_refresh_home()
	_refresh_bank()
	_refresh_mickey()
	_refresh_health()
	_refresh_paths()
	_refresh_town()


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
	if job.requires_clean_record and sheet.has_tag("the_record") \
			and not sheet.flags.get("record_sealed", false):
		return "background check"
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


# ------------------------------------------------------------------- home

func _refresh_home() -> void:
	_clear(_home_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	var current := ContentDB.get_housing(sheet.housing_id)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Home: %s%s    Credit: %d    Outfit tier: %d" % [
		current.display_name if current else "the street",
		" (owned)" if sheet.flags.get("home_owned", false) else "",
		sheet.credit_score, sheet.outfit_tier()]
	status.add_theme_font_size_override("font_size", 13)
	_home_box.add_child(status)

	var market := Label.new()
	market.text = "— THE MARKET (rent Mondays; landlords judge shoes) —"
	market.add_theme_font_size_override("font_size", 11)
	market.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_home_box.add_child(market)

	for def in ContentDB.all_housings():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_home_box.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 12)
		var price := "$%d/wk + $%d deposit" % [def.weekly_rent_cents / 100, def.deposit_cents / 100] \
				if def.weekly_rent_cents > 0 else "free"
		info.text = "T%d %s — %s\n%s" % [def.tier, def.display_name, price, def.blurb]
		row.add_child(info)

		var rent_btn := Button.new()
		rent_btn.custom_minimum_size = Vector2(120, 0)
		var blocker := Housing.rent_blocker(sheet, def)
		if blocker == "":
			rent_btn.text = "Move in"
			rent_btn.pressed.connect(func() -> void:
				Housing.move_in(sheet, def)
				_refresh_home())
		else:
			rent_btn.text = blocker
			rent_btn.disabled = true
		row.add_child(rent_btn)

		if def.buy_price_cents > 0:
			var buy_btn := Button.new()
			buy_btn.custom_minimum_size = Vector2(140, 0)
			var buy_blocker := Housing.buy_blocker(sheet, def)
			if buy_blocker == "":
				buy_btn.text = "Buy ($%dk down)" % (def.down_payment_cents / 100000)
				buy_btn.pressed.connect(func() -> void:
					Housing.buy(sheet, def)
					_refresh_home())
			else:
				buy_btn.text = buy_blocker
				buy_btn.disabled = true
			row.add_child(buy_btn)

	# Wheels: fast-travel with a steering wheel attached.
	if not sheet.flags.get("has_car", false):
		var car := Button.new()
		car.text = "Buy the $800 beater (it runs. mostly.)"
		car.disabled = sheet.cash_cents < 80000
		car.pressed.connect(func() -> void:
			sheet.add_cash(-80000)
			sheet.flags["has_car"] = true
			EventBus.toast.emit("The beater coughs to life. The town just got smaller.")
			_refresh_home())
		_home_box.add_child(car)

	var shop := Label.new()
	shop.text = "— FURNITURE (a $30 mattress and a $3,000 bed are different lives) —"
	shop.add_theme_font_size_override("font_size", 11)
	shop.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_home_box.add_child(shop)

	for f in ContentDB.all_furniture():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_home_box.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 12)
		info.text = "%s — $%.2f\n%s" % [f.display_name, f.cost_cents / 100.0, f.blurb]
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 0)
		if f.id in sheet.furniture:
			btn.text = "Owned ✓"
			btn.disabled = true
		elif sheet.housing_id == "":
			btn.text = "no home"
			btn.disabled = true
		elif sheet.cash_cents < f.cost_cents:
			btn.text = "can't afford"
			btn.disabled = true
		else:
			btn.text = "Buy"
			btn.pressed.connect(func() -> void:
				sheet.add_cash(-f.cost_cents)
				sheet.furniture.append(f.id)
				EventBus.toast.emit("Delivered: %s. Home gains a personality." % f.display_name)
				_refresh_home())
		row.add_child(btn)


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


# ------------------------------------------------------------------ health

func _refresh_health() -> void:
	_clear(_health_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	var vitals := Label.new()
	vitals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spouse: NPCRecord = WorldState.npcs.get(str(sheet.flags.get("spouse_id", "")))
	vitals.text = "Age %d · %.1f kg · %d/32 teeth · %d scar%s%s%s" % [
		int(sheet.age_years), sheet.weight_kg,
		int(sheet.flags.get("teeth", Body.TEETH_FULL)),
		int(sheet.flags.get("scars", 0)), "" if int(sheet.flags.get("scars", 0)) == 1 else "s",
		"\nMarried to %s" % spouse.display_name if spouse else "",
		"\nChildren: %d" % sheet.children.size() if not sheet.children.is_empty() else ""]
	vitals.add_theme_font_size_override("font_size", 13)
	_health_box.add_child(vitals)

	if sheet.wounds.is_empty():
		var fine := Label.new()
		fine.text = "No open wounds. The body forgives. The body also keeps a list."
		fine.add_theme_font_size_override("font_size", 12)
		_health_box.add_child(fine)
	else:
		for w in sheet.wounds:
			var lbl := Label.new()
			lbl.text = "• %s — %d day%s left%s" % [str(w.kind), int(w.days_left),
					"" if int(w.days_left) == 1 else "s",
					" (treated)" if w.get("treated", false) else " (UNTREATED — may heal wrong)"]
			lbl.add_theme_font_size_override("font_size", 12)
			_health_box.add_child(lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_health_box.add_child(row)
	var is_doctor := sheet.has_tag("medical_training")
	_health_button(row, "Treat yourself (free — you trained for this)" if is_doctor else "County clinic ($150)",
		(is_doctor or sheet.cash_cents >= 15000) and not sheet.wounds.is_empty(),
		func() -> void:
			if not is_doctor:
				sheet.add_cash(-15000)
			var n := Body.treat_wounds(sheet)
			GameClock.skip_minutes(60 if is_doctor else 180)
			EventBus.toast.emit("%d wound%s set properly.%s" % [n, "" if n == 1 else "s",
					" The hands still remember." if is_doctor else " The bill stings more than the sutures."])
			_refresh_health())
	_health_button(row, "Back-alley doc ($40)", sheet.cash_cents + sheet.dirty_cents >= 4000 and not sheet.wounds.is_empty(),
		func() -> void:
			var from_dirty: int = mini(sheet.dirty_cents, 4000)
			sheet.dirty_cents -= from_dirty
			if 4000 - from_dirty > 0:
				sheet.add_cash(-(4000 - from_dirty))
			var n := Body.treat_wounds(sheet)
			if randf() < 0.2:
				sheet.flags["scars"] = int(sheet.flags.get("scars", 0)) + 1
				EventBus.toast.emit("He fixed %d wound%s. One of them will have a story." % [n, "" if n == 1 else "s"])
			else:
				EventBus.toast.emit("Cheap, quick, no questions. %d wound%s handled." % [n, "" if n == 1 else "s"])
			_refresh_health())

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_health_box.add_child(row2)
	if int(sheet.flags.get("teeth", Body.TEETH_FULL)) <= 27 and not sheet.flags.get("dentures", false):
		_health_button(row2, "Dentures ($300)", sheet.cash_cents >= 30000,
			func() -> void:
				sheet.add_cash(-30000)
				sheet.flags["dentures"] = true
				EventBus.toast.emit("A full smile again. Slightly too white. Nobody mentions it twice.")
				_refresh_health())
	if int(sheet.flags.get("cha_surgery", 0)) < 2:
		_health_button(row2, "Plastic surgery ($2,000)", sheet.cash_cents >= 200000,
			func() -> void:
				sheet.add_cash(-200000)
				if randf() < 0.1:
					sheet.flags["cha_botched"] = true
					EventBus.toast.emit("The surgeon said 'oops' in there. You both heard it.")
				else:
					sheet.flags["cha_surgery"] = int(sheet.flags.get("cha_surgery", 0)) + 1
					sheet.flags["scars"] = 0
					EventBus.toast.emit("New face, who's this? CHA up; the scars are someone else's now.")
				_refresh_health())


func _health_button(parent: Node, label: String, enabled: bool, action: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.disabled = not enabled
	btn.pressed.connect(action)
	parent.add_child(btn)


# -------------------------------------------------------------------- town

func _refresh_town() -> void:
	_clear(_town_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	status.text = "Town fear: %d/100%s    Fame %d · Infamy %d%s" % [
		int(WorldState.town_fear),
		"  (streets emptying)" if WorldState.town_fear >= 40.0 else "",
		int(sheet.fame), int(sheet.infamy),
		"\nYou are the MAYOR. Nobody audits the winner." if sheet.flags.get("is_mayor", false) else ""]
	_town_box.add_child(status)

	# Politics: buy in, or buy the office.
	var politics := HBoxContainer.new()
	politics.add_theme_constant_override("separation", 8)
	_town_box.add_child(politics)
	if sheet.flags.get("is_mayor", false):
		var budget := Button.new()
		budget.text = "Police budget: %s (toggle)" % ("GUTTED" if sheet.flags.get("police_budget_low", false) else "normal")
		budget.pressed.connect(func() -> void:
			sheet.flags["police_budget_low"] = not sheet.flags.get("police_budget_low", false)
			EventBus.toast.emit("Patrols %s. The Gazette calls it 'fiscal discipline'." %
					("thinned" if sheet.flags.police_budget_low else "restored"))
			_refresh_town())
		politics.add_child(budget)
	else:
		var run := Button.new()
		var spend := int(sheet.flags.get("campaign_spend", 0))
		run.text = "Donate $1,000 to your own campaign%s" % \
				("" if spend == 0 else "  (spent: $%d, score %.0f)" % [spend / 100, TownLife.player_election_score(sheet)])
		run.disabled = sheet.cash_cents + sheet.dirty_cents < 100000
		run.tooltip_text = "Dirty money welcome. That's the whole point of local politics."
		run.pressed.connect(func() -> void:
			if TownLife.donate_to_campaign(sheet, 100000):
				EventBus.toast.emit("Yard signs everywhere. Election is day %d." %
						((GameClock.day / TownLife.ELECTION_PERIOD_DAYS + 1) * TownLife.ELECTION_PERIOD_DAYS))
			_refresh_town())
		politics.add_child(run)

	# Business: the late-game engine. Buy the laundromat; learn why.
	var biz_row := HBoxContainer.new()
	biz_row.add_theme_constant_override("separation", 8)
	_town_box.add_child(biz_row)
	for biz_id in TownLife.BUSINESSES:
		var biz: Dictionary = TownLife.BUSINESSES[biz_id]
		var btn := Button.new()
		if biz_id in sheet.flags.get("businesses", []):
			btn.text = "%s ✓ ($%d/day)" % [biz.name, int(biz.net) / 100]
			btn.disabled = true
		else:
			btn.text = "Buy %s ($%dk)" % [biz.name, int(biz.cost) / 100000]
			btn.disabled = sheet.cash_cents < int(biz.cost)
			btn.tooltip_text = "Nets $%d/day and washes $%d/day of dirty money at 80 cents on the dollar." % [
					int(biz.net) / 100, int(biz.wash_cap) / 100]
			btn.pressed.connect(func() -> void:
				TownLife.buy_business(sheet, biz_id)
				_refresh_town())
		biz_row.add_child(btn)

	var masthead := Label.new()
	masthead.text = "— THE RUST HARBOR GAZETTE —"
	masthead.add_theme_font_size_override("font_size", 12)
	masthead.add_theme_color_override("font_color", Color(0.7, 0.68, 0.55))
	_town_box.add_child(masthead)
	var news: Array = WorldState.gazette.duplicate()
	news.reverse()
	for i in mini(news.size(), 15):
		var item: Dictionary = news[i]
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 12)
		line.text = "Day %d — %s" % [int(item.day), str(item.text)]
		_town_box.add_child(line)
	if news.is_empty():
		var quiet := Label.new()
		quiet.text = "No news. In this town, that's the headline."
		_town_box.add_child(quiet)


# ------------------------------------------------------------------- paths

func _refresh_paths() -> void:
	_clear(_paths_box)
	var sheet: CharacterSheet = WorldState.player_sheet
	# Night school: the Education path's enroll button lives here.
	if not sheet.flags.get("ged", false) and not sheet.flags.has("ged_done_day"):
		var ged := Button.new()
		ged.text = "Enroll: GED night classes ($200, 14 days)"
		ged.disabled = sheet.cash_cents < 20000
		ged.pressed.connect(func() -> void:
			sheet.add_cash(-20000)
			sheet.flags["ged_done_day"] = GameClock.day + 14
			EventBus.toast.emit("Enrolled. Tuesdays and Thursdays now taste like burnt coffee.")
			EventBus.path_updated.emit()
			_refresh_paths())
		_paths_box.add_child(ged)
	# Perks: a fork every two levels. New verbs over numbers.
	var perk_points := int(sheet.flags.get("perk_points", 0))
	var perk_header := Label.new()
	perk_header.text = "— LEVEL %d · %d XP · %d perk point%s —" % [
		sheet.level, sheet.xp, perk_points, "" if perk_points == 1 else "s"]
	perk_header.add_theme_font_size_override("font_size", 11)
	perk_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_paths_box.add_child(perk_header)
	for perk in ContentDB.perks.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_paths_box.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 12)
		info.text = "%s (lvl %d) — %s" % [perk.display_name, perk.min_level, perk.description]
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 0)
		if sheet.has_perk(perk.id):
			btn.text = "Taken ✓"
			btn.disabled = true
		else:
			btn.text = "Take"
			btn.disabled = perk_points <= 0 or sheet.level < perk.min_level
			btn.pressed.connect(func() -> void:
				if sheet.take_perk(perk.id):
					EventBus.toast.emit("Perk: %s. A new verb unlocked." % perk.display_name)
				_refresh_paths())
		row.add_child(btn)
	# Walking Away: retirement, the other way out. The sim takes the wheel.
	var walk := Button.new()
	walk.text = "Walk Away (retire this life — they become an NPC)"
	walk.pressed.connect(func() -> void:
		var npc := WorldState.walk_away()
		if npc != null:
			_close()
			EventBus.toast.emit("%s's life goes on without you at the wheel." % npc.display_name)
			GameFlow.to_character_creation())
	_paths_box.add_child(walk)
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
