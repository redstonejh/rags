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
var _people_box: VBoxContainer
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


func open_tab(tab_name: String) -> bool:
	if _tabs == null:
		return false
	for i in _tabs.get_tab_count():
		if _tabs.get_tab_title(i) == tab_name:
			_tabs.current_tab = i
			return true
	return false


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
	_people_box = _make_tab("People")
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
	box.name = "%sContent" % tab_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _refresh_all() -> void:
	_refresh_jobs()
	_refresh_home()
	_refresh_people()
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


# ----------------------------------------------------------------- people

func _refresh_people() -> void:
	_clear(_people_box)
	var people: Array = []
	var hidden_count := 0
	for candidate in WorldState.npcs.values():
		var npc: NPCRecord = candidate
		if npc == null or not npc.alive:
			continue
		if _people_is_known(npc):
			people.append(npc)
		else:
			hidden_count += 1
	people.sort_custom(func(a: NPCRecord, b: NPCRecord) -> bool:
		var score_a := _people_sort_score(a)
		var score_b := _people_sort_score(b)
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return a.display_name.to_lower() < b.display_name.to_lower())

	var header := Label.new()
	header.name = "PeopleHeader"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.text = "PEOPLE - %d known contact%s%s" % [
		people.size(),
		"" if people.size() == 1 else "s",
		" (%d townsfolk still unknown)" % hidden_count if hidden_count > 0 else ""]
	header.add_theme_font_size_override("font_size", 13)
	_people_box.add_child(header)

	if people.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "No contacts yet. Talk to people, date them, wrong them, or become gossip-worthy."
		_people_box.add_child(empty)
		return

	for i in mini(people.size(), 40):
		var npc: NPCRecord = people[i]
		var row := VBoxContainer.new()
		row.name = "PeopleRow"
		row.add_theme_constant_override("separation", 2)
		_people_box.add_child(row)

		var title := Label.new()
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 13)
		title.text = "%s - %s%s" % [
			npc.display_name,
			_people_rel_text(npc.rel("player")),
			_people_partner_suffix(npc)]
		row.add_child(title)

		var details := Label.new()
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_theme_font_size_override("font_size", 11)
		details.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		var detail_lines: Array[String] = [
			"%s at %s - %s" % [
				_people_role(npc),
				Locations.display_name(npc.current_location_id),
				_people_connections_text(npc)],
		]
		var family := _people_family_text(npc)
		if family != "":
			detail_lines.append(family)
		detail_lines.append(_people_gossip_text(npc))
		var history := _people_story_history_text(npc)
		if history != "":
			detail_lines.append(history)
		details.text = "\n".join(detail_lines)
		row.add_child(details)


func _people_sort_score(npc: NPCRecord) -> float:
	var score := absf(npc.rel("player"))
	if npc.flags.get("dating_player", false):
		score += 75.0
	if npc.flags.get("married_to_player", false):
		score += 100.0
	for memory in npc.memories:
		if memory.get("subject", "") == "player":
			score += float(memory.get("salience", 0.0))
	return score


func _people_is_known(npc: NPCRecord) -> bool:
	if absf(npc.rel("player")) > 0.01:
		return true
	if npc.flags.get("dating_player", false) or npc.flags.get("married_to_player", false):
		return true
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet != null and str(sheet.flags.get("spouse_id", "")) == npc.id:
		return true
	for memory in npc.memories:
		if memory.get("subject", "") == "player":
			return true
		if memory.get("source_id", "") == "player":
			return true
	return false


func _people_rel_text(value: float) -> String:
	var label := "neutral"
	if value >= 75.0:
		label = "devoted"
	elif value >= 40.0:
		label = "friendly"
	elif value >= 15.0:
		label = "warm"
	elif value <= -75.0:
		label = "enemy"
	elif value <= -40.0:
		label = "hostile"
	elif value <= -15.0:
		label = "sour"
	return "%s (%s)" % [label, _signed_int(value)]


func _people_partner_suffix(npc: NPCRecord) -> String:
	if _people_is_player_spouse(npc):
		return " - married to you"
	if npc.flags.get("dating_player", false):
		return " - dating you"
	return ""


func _people_role(npc: NPCRecord) -> String:
	var archetype := npc.archetype()
	return archetype.display_name if archetype != null else npc.archetype_id.capitalize()


func _people_connections_text(npc: NPCRecord) -> String:
	var parts: Array[String] = []
	if npc.flags.get("married_to_player", false):
		parts.append("married to you")
	elif npc.flags.get("dating_player", false):
		parts.append("dating you")

	var close_links: Array[Dictionary] = []
	var feud_links: Array[Dictionary] = []
	for other_id in npc.relationships:
		if str(other_id) == "player":
			continue
		var value := float(npc.relationships[other_id])
		if value >= 35.0:
			close_links.append({"id": str(other_id), "value": value})
		elif value <= -35.0:
			feud_links.append({"id": str(other_id), "value": value})
	close_links.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("value", 0.0)) > float(b.get("value", 0.0)))
	feud_links.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("value", 0.0)) < float(b.get("value", 0.0)))
	if not close_links.is_empty():
		parts.append("close to %s" % _people_relationship_list(close_links, 2))
	if not feud_links.is_empty():
		parts.append("feuding with %s" % _people_relationship_list(feud_links, 2))
	return "Status: %s" % ("; ".join(parts) if not parts.is_empty() else "no public entanglements")


func _people_relationship_list(links: Array[Dictionary], limit: int) -> String:
	var names: Array[String] = []
	for i in mini(links.size(), limit):
		var link := links[i]
		names.append("%s (%s)" % [
			_npc_name(str(link.get("id", ""))),
			_signed_int(float(link.get("value", 0.0)))])
	return ", ".join(names)


func _people_family_text(npc: NPCRecord) -> String:
	var parts: Array[String] = []
	if _people_is_player_spouse(npc):
		parts.append("spouse")
		var sheet: CharacterSheet = WorldState.player_sheet
		if sheet != null and not sheet.children.is_empty():
			parts.append("%d child%s" % [
				sheet.children.size(),
				"" if sheet.children.size() == 1 else "ren"])
	var spouse_id := str(npc.flags.get("spouse_id", ""))
	if spouse_id != "" and spouse_id != "player":
		parts.append("married to %s" % _npc_name(spouse_id))
	var child_count := int(npc.flags.get("children_count", 0))
	if child_count > 0:
		parts.append("%d child%s" % [child_count, "" if child_count == 1 else "ren"])
	return ("Family: %s" % "; ".join(parts)) if not parts.is_empty() else ""


func _people_gossip_text(npc: NPCRecord) -> String:
	var story := npc.top_gossip(3.0)
	if story.is_empty():
		return "Gossip: nothing useful yet."
	var phrase := _people_memory_phrase(npc, story)
	if story.get("secondhand", false):
		return "Gossip: %s heard from %s that %s - D%d" % [
			npc.display_name.get_slice(" ", 0),
			_people_gossip_source_chain(story),
			phrase,
			int(story.get("day", 0))]
	return "Gossip: %s remembers %s - D%d" % [
		npc.display_name.get_slice(" ", 0),
		phrase,
		int(story.get("day", 0))]


func _people_gossip_source_chain(story: Dictionary) -> String:
	var source_id := str(story.get("source_id", ""))
	var previous_id := str(story.get("previous_source_id", ""))
	if previous_id != "" and previous_id != source_id:
		return "%s via %s" % [_npc_name(source_id), _npc_name(previous_id)]
	return _npc_name(source_id)


func _people_story_history_text(npc: NPCRecord) -> String:
	var stories: Array[Dictionary] = []
	for memory in npc.memories:
		if float(memory.get("salience", 0.0)) < 3.0:
			continue
		if str(memory.get("subject", "")) != "player" \
				and str(memory.get("source_id", "")) != "player":
			continue
		stories.append(memory)
	if stories.is_empty():
		return ""
	stories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var salience_a := float(a.get("salience", 0.0))
		var salience_b := float(b.get("salience", 0.0))
		if not is_equal_approx(salience_a, salience_b):
			return salience_a > salience_b
		return int(a.get("day", 0)) > int(b.get("day", 0)))
	if stories.size() > 3:
		stories.resize(3)
	var lines: Array[String] = []
	for story in stories:
		var source := ""
		if story.get("secondhand", false):
			source = " via %s" % _people_gossip_source_chain(story)
		lines.append("D%d %s%s" % [
			int(story.get("day", 0)),
			_people_memory_phrase(npc, story),
			source])
	return "Stories: %s" % "; ".join(lines)


func _people_memory_phrase(npc: NPCRecord, story: Dictionary) -> String:
	var subject_id := str(story.get("subject", ""))
	var text := str(story.get("text", "did something"))
	if subject_id == "player":
		var npc_first := npc.display_name.get_slice(" ", 0)
		text = text.replace("misjudged you", "misjudged %s" % npc_first)
		text = text.replace("you put them right", "%s put you right" % npc_first)
		return "you %s" % text
	return "%s %s" % [_npc_name(subject_id), text]


func _npc_name(npc_id: String) -> String:
	if npc_id == "":
		return "someone"
	if npc_id == "player":
		return "you"
	var npc: NPCRecord = WorldState.npcs.get(npc_id)
	return npc.display_name if npc != null else npc_id


func _people_is_player_spouse(npc: NPCRecord) -> bool:
	var sheet: CharacterSheet = WorldState.player_sheet
	return npc.flags.get("married_to_player", false) \
			or (sheet != null and str(sheet.flags.get("spouse_id", "")) == npc.id)


func _signed_int(value: float) -> String:
	var rounded := roundi(value)
	return "+%d" % rounded if rounded > 0 else str(rounded)


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
