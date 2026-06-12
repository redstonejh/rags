extends CanvasLayer
## HUD: need bars (built dynamically from the sheet, including optional bars
## like craving), money (both kinds), mood, weight, job line, clock, toasts.
## Updated via EventBus signals; the slow-moving labels refresh on the minute.

const BAR_COLORS := {
	"hunger": Color(0.85, 0.5, 0.15),
	"energy": Color(0.25, 0.65, 0.85),
	"hygiene": Color(0.45, 0.75, 0.7),
	"fun": Color(0.7, 0.5, 0.85),
	"social": Color(0.5, 0.8, 0.45),
	"craving": Color(0.85, 0.25, 0.3),
}
const BAR_ORDER := ["hunger", "energy", "hygiene", "fun", "social", "craving"]
const TOAST_SECONDS := 4.0
const MAX_TOASTS := 3

@onready var name_label: Label = %NameLabel
@onready var cash_label: Label = %CashLabel
@onready var dirty_label: Label = %DirtyLabel
@onready var mood_label: Label = %MoodLabel
@onready var weight_label: Label = %WeightLabel
@onready var job_label: Label = %JobLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var wanted_label: Label = %WantedLabel
@onready var clock_label: Label = %ClockLabel
@onready var speed_label: Label = %SpeedLabel
@onready var bars_box: VBoxContainer = %BarsBox
@onready var prompt_label: Label = %PromptLabel
@onready var toast_box: VBoxContainer = %ToastBox

var _bars: Dictionary = {}
var _current_prompt := ""


func _ready() -> void:
	EventBus.minute_passed.connect(func(_t: int) -> void: _update_slow_labels())
	EventBus.time_scale_changed.connect(_on_time_scale_changed)
	EventBus.player_need_changed.connect(_on_need_changed)
	EventBus.money_changed.connect(func(_c: int) -> void:
		_update_money()
		_update_objective_label())
	EventBus.interact_target_changed.connect(_set_prompt)
	EventBus.player_job_changed.connect(func(_id: String) -> void:
		_update_job_label()
		_update_objective_label())
	EventBus.wanted_changed.connect(_on_wanted_changed)
	EventBus.toast.connect(_on_toast)

	_build_bars()
	_on_time_scale_changed(GameClock.time_scale)
	prompt_label.text = ""
	if WorldState.player_sheet:
		name_label.text = WorldState.player_sheet.char_name
	_update_money()
	_update_job_label()
	_update_slow_labels()


# ------------------------------------------------------------------- bars

func _build_bars() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		return
	var ids: Array = []
	for id in BAR_ORDER:
		if sheet.needs.values.has(id):
			ids.append(id)
	for id in sheet.needs.values: # any future optional bars
		if id not in ids:
			ids.append(id)
	for id in ids:
		var label := Label.new()
		label.text = id.capitalize()
		label.add_theme_font_size_override("font_size", 12)
		bars_box.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 14)
		bar.max_value = 100.0
		bar.value = sheet.needs.get_value(id)
		bar.show_percentage = false
		_style_bar(bar, BAR_COLORS.get(id, Color(0.6, 0.6, 0.6)))
		bars_box.add_child(bar)
		_bars[id] = bar


func _on_need_changed(need_id: String, value: float) -> void:
	if _bars.has(need_id):
		var bar: ProgressBar = _bars[need_id]
		bar.value = value
		# Flash toward red as a need bottoms out.
		var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
		if fill:
			var base: Color = BAR_COLORS.get(need_id, Color(0.6, 0.6, 0.6))
			fill.bg_color = base if value > 25.0 else base.lerp(Color(0.9, 0.15, 0.1), 0.6)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


# ------------------------------------------------------------------- labels

func _update_money() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		return
	cash_label.text = "$%.2f" % (sheet.cash_cents / 100.0)
	dirty_label.visible = sheet.dirty_cents > 0
	dirty_label.text = "+$%.2f dirty" % (sheet.dirty_cents / 100.0)


func _update_slow_labels() -> void:
	clock_label.text = GameClock.time_string()
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		return
	mood_label.text = "Mood %d" % int(sheet.mood())
	weight_label.text = "%.1f kg" % sheet.weight_kg
	_update_money() # dirty cash has no signal; piggyback the minute tick
	_update_objective_label()


func _on_wanted_changed(stars: int) -> void:
	wanted_label.visible = stars > 0
	wanted_label.text = "★".repeat(stars) + "  WANTED"


func _update_job_label() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var job := sheet.job() if sheet else null
	if job == null:
		job_label.text = "Unemployed (Tab: job board)"
		return
	var on_today := (GameClock.day % 7) in job.work_days
	job_label.text = "%s @ %s — %d:00%s" % [
		job.display_name, Locations.display_name(job.workplace_id),
		job.shift_start_hour, "" if on_today else " (off today)"]


func _update_objective_label() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		objective_label.text = ""
		objective_label.visible = false
		return
	objective_label.visible = true
	for path in LifePaths.evaluate(sheet):
		for step in path.steps:
			if bool(step.get("current", false)):
				objective_label.text = "%s: %s" % [str(path.name), str(step.label)]
				return
	objective_label.text = "Paths: open the phone for longer-term goals"


func _on_time_scale_changed(scale: float) -> void:
	if scale == 0.0:
		speed_label.text = "Paused  Space / 1 2 3"
	else:
		speed_label.text = "%dx  Space / 1 2 3" % int(scale)
	_sync_prompt_label()


func _set_prompt(prompt: String) -> void:
	_current_prompt = prompt
	_sync_prompt_label()


func _sync_prompt_label() -> void:
	prompt_label.text = "" if GameClock.paused else _current_prompt
	prompt_label.visible = not GameClock.paused and _current_prompt != ""


# ------------------------------------------------------------------- toasts

func _on_toast(message: String) -> void:
	while toast_box.get_child_count() >= MAX_TOASTS:
		toast_box.get_child(0).free()
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	toast_box.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
