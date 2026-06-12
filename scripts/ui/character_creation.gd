extends Control
## Character creation: origin (class) picker -> D&D point-buy -> trait budget
## -> name, plus "Deal Me a Life" coherent random generation with per-category
## locks. Most UI is built in code; the .tscn only holds the layout skeleton.

var origin_id: String = ""
var base_stats: Dictionary = {}
var trait_ids: Array = []
var appearance_tags: Array = []
var bio: String = ""

var _origin_buttons: Dictionary = {}
var _stat_value_labels: Dictionary = {}
var _stat_final_labels: Dictionary = {}
var _trait_checks: Dictionary = {}

@onready var origin_list: VBoxContainer = %OriginList
@onready var origin_info: RichTextLabel = %OriginInfo
@onready var stats_grid: GridContainer = %StatsGrid
@onready var points_label: Label = %PointsLabel
@onready var trait_list: VBoxContainer = %TraitList
@onready var budget_label: Label = %BudgetLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var bio_label: Label = %BioLabel
@onready var start_button: Button = %StartButton
@onready var lock_origin: CheckBox = %LockOrigin
@onready var lock_stats: CheckBox = %LockStats
@onready var lock_traits: CheckBox = %LockTraits
@onready var lock_name: CheckBox = %LockName


func _ready() -> void:
	for s in CharacterSheet.STAT_IDS:
		base_stats[s] = CharacterSheet.STAT_BASE
	_build_origin_list()
	_build_stats_grid()
	_build_trait_list()
	%DealButton.pressed.connect(_on_deal_pressed)
	%BackButton.pressed.connect(func() -> void: GameFlow.to_main_menu())
	start_button.pressed.connect(_on_start_pressed)
	name_edit.text_changed.connect(func(_t: String) -> void: _refresh())
	# Lives after the first get numbered — the town remembers the others.
	if WorldState.world_exists and not WorldState.npcs.is_empty() \
			and WorldState.player_sheet != null and not WorldState.player_sheet.alive:
		var header: Label = $Margin/Root/Header
		header.text = "Life #%d in Rust Harbor — who are you this time?" \
				% (WorldState.player_sheet.lives_lived + 1)
	if not ContentDB.all_origins().is_empty():
		_select_origin(ContentDB.all_origins()[0].id)
	_refresh()


# ---------------------------------------------------------------- origins

func _build_origin_list() -> void:
	for origin in ContentDB.all_origins():
		var b := Button.new()
		b.text = "%s %s" % ["★".repeat(origin.difficulty), origin.display_name]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.pressed.connect(_select_origin.bind(origin.id))
		origin_list.add_child(b)
		_origin_buttons[origin.id] = b


func _select_origin(id: String) -> void:
	origin_id = id
	for oid in _origin_buttons:
		_origin_buttons[oid].button_pressed = (oid == id)
	var origin := ContentDB.get_origin(id)
	origin_info.text = "[b]%s[/b]\n[i]\"%s\"[/i]\n\n%s\n\n[b]Starting cash:[/b] $%.2f" % [
		origin.display_name, origin.title, origin.blurb,
		origin.starting_cash_cents / 100.0]
	# Origin changes can invalidate trait picks (locked/free lists differ).
	trait_ids = trait_ids.filter(func(tid: String) -> bool:
		return tid not in origin.locked_traits and tid not in origin.free_traits)
	_refresh()


# ---------------------------------------------------------------- stats

func _build_stats_grid() -> void:
	for s in CharacterSheet.STAT_IDS:
		var name_label := Label.new()
		name_label.text = s
		name_label.custom_minimum_size = Vector2(46, 0)
		stats_grid.add_child(name_label)

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(32, 0)
		minus.pressed.connect(_change_stat.bind(s, -1))
		stats_grid.add_child(minus)

		var value := Label.new()
		value.text = "8"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.custom_minimum_size = Vector2(30, 0)
		stats_grid.add_child(value)
		_stat_value_labels[s] = value

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(32, 0)
		plus.pressed.connect(_change_stat.bind(s, 1))
		stats_grid.add_child(plus)

		var final := Label.new()
		final.custom_minimum_size = Vector2(70, 0)
		final.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		stats_grid.add_child(final)
		_stat_final_labels[s] = final


func _change_stat(stat: String, dir: int) -> void:
	var v: int = base_stats[stat]
	if dir > 0:
		var cost := CharacterSheet.step_cost(v)
		if v < CharacterSheet.STAT_CAP \
				and CharacterSheet.points_spent(base_stats) + cost <= CharacterSheet.POINT_POOL:
			base_stats[stat] = v + 1
	else:
		if v > CharacterSheet.STAT_BASE:
			base_stats[stat] = v - 1
	_refresh()


# ---------------------------------------------------------------- traits

func _build_trait_list() -> void:
	for t in ContentDB.all_traits():
		var check := CheckBox.new()
		var sign := "+" if t.point_cost >= 0 else ""
		check.text = "%s  (%s%d)" % [t.display_name, sign, t.point_cost]
		check.tooltip_text = t.description
		check.toggled.connect(_on_trait_toggled.bind(t.id))
		trait_list.add_child(check)
		_trait_checks[t.id] = check


func _on_trait_toggled(on: bool, tid: String) -> void:
	if on and tid not in trait_ids:
		trait_ids.append(tid)
	elif not on:
		trait_ids.erase(tid)
	_refresh()


# ---------------------------------------------------------------- random

func _on_deal_pressed() -> void:
	var locks := {
		"origin": lock_origin.button_pressed,
		"stats": lock_stats.button_pressed,
		"traits": lock_traits.button_pressed,
		"name": lock_name.button_pressed,
	}
	var current := {
		"origin_id": origin_id,
		"base_stats": base_stats,
		"trait_ids": trait_ids,
		"char_name": name_edit.text,
	}
	var dealt := Coherence.deal(locks, current)
	origin_id = dealt.origin_id
	base_stats = dealt.base_stats
	trait_ids = dealt.trait_ids
	appearance_tags = dealt.appearance_tags
	bio = dealt.bio
	name_edit.text = dealt.char_name
	_select_origin(origin_id) # also refreshes; note: re-filters traits vs origin
	trait_ids = dealt.trait_ids.filter(func(tid: String) -> bool:
		var origin := ContentDB.get_origin(origin_id)
		return tid not in origin.locked_traits and tid not in origin.free_traits)
	bio_label.text = bio
	_refresh()


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	var origin := ContentDB.get_origin(origin_id)

	var spent := CharacterSheet.points_spent(base_stats)
	points_label.text = "Stat points: %d / %d" % [spent, CharacterSheet.POINT_POOL]
	for s in CharacterSheet.STAT_IDS:
		_stat_value_labels[s].text = str(base_stats[s])
		var mod := int(origin.stat_mods.get(s, 0)) if origin else 0
		for tid in trait_ids:
			var t := ContentDB.get_trait(tid)
			if t:
				mod += int(t.stat_mods.get(s, 0))
		var final: int = base_stats[s] + mod
		_stat_final_labels[s].text = "= %d (%+d)" % [final, mod] if mod != 0 else "= %d" % final

	var budget := _current_budget()
	budget_label.text = "Trait points: %+d  %s" % [budget, "✓" if budget <= 0 else "— overspent!"]
	budget_label.add_theme_color_override("font_color",
			Color(0.4, 0.85, 0.4) if budget <= 0 else Color(0.9, 0.3, 0.25))

	for tid in _trait_checks:
		var check: CheckBox = _trait_checks[tid]
		var t := ContentDB.get_trait(tid)
		check.set_pressed_no_signal(tid in trait_ids)
		var locked: bool = origin != null and tid in origin.locked_traits
		var free: bool = origin != null and tid in origin.free_traits
		var conflicted := false
		for pid in trait_ids:
			if pid == tid:
				continue
			var p := ContentDB.get_trait(pid)
			if p and (tid in p.conflicts_with or pid in t.conflicts_with):
				conflicted = true
		check.disabled = locked or free or conflicted
		var sign := "+" if t.point_cost >= 0 else ""
		var suffix := "  — locked by origin" if locked else ("  — FREE from origin" if free else "")
		check.text = "%s  (%s%d)%s" % [t.display_name, sign, t.point_cost, suffix]
		if free:
			check.set_pressed_no_signal(true)

	start_button.disabled = origin == null \
			or name_edit.text.strip_edges() == "" \
			or budget > 0 \
			or spent > CharacterSheet.POINT_POOL


func _current_budget() -> int:
	var origin := ContentDB.get_origin(origin_id)
	var total := -(origin.bonus_trait_points if origin else 0)
	for tid in trait_ids:
		var t := ContentDB.get_trait(tid)
		if t:
			total += t.point_cost
	return total


# ---------------------------------------------------------------- start

func _on_start_pressed() -> void:
	var origin := ContentDB.get_origin(origin_id)
	var sheet := CharacterSheet.new()
	sheet.char_name = name_edit.text.strip_edges()
	sheet.origin_id = origin_id
	sheet.base_stats = base_stats.duplicate()
	sheet.trait_ids = trait_ids.duplicate()
	for tid in origin.free_traits:
		if tid not in sheet.trait_ids:
			sheet.trait_ids.append(tid)
	sheet.appearance_tags = appearance_tags.duplicate()
	sheet.bio = bio
	sheet.cash_cents = origin.starting_cash_cents
	sheet.skills = origin.skill_seeds.duplicate()
	sheet.inventory = origin.starting_items.duplicate()
	sheet.housing_id = origin.starting_housing_id
	for flag in origin.starting_flags:
		sheet.flags[flag] = origin.starting_flags[flag]
	GameFlow.start_new_game(sheet)
