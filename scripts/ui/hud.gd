extends CanvasLayer
## HUD: need bars, clock, time-speed indicator, interaction prompt.
## Updated entirely via EventBus signals — never polls game state.

@onready var name_label: Label = %NameLabel
@onready var cash_label: Label = %CashLabel
@onready var clock_label: Label = %ClockLabel
@onready var speed_label: Label = %SpeedLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var prompt_label: Label = %PromptLabel

var _bars: Dictionary = {}


func _ready() -> void:
	_bars = {"hunger": hunger_bar, "energy": energy_bar}
	_style_bar(hunger_bar, Color(0.85, 0.5, 0.15))
	_style_bar(energy_bar, Color(0.25, 0.65, 0.85))

	EventBus.minute_passed.connect(func(_t: int) -> void: _update_clock())
	EventBus.time_scale_changed.connect(_on_time_scale_changed)
	EventBus.player_need_changed.connect(_on_need_changed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.interact_target_changed.connect(func(p: String) -> void: prompt_label.text = p)

	_update_clock()
	_on_time_scale_changed(GameClock.time_scale)
	prompt_label.text = ""
	if WorldState.player_sheet:
		name_label.text = WorldState.player_sheet.char_name
		_on_money_changed(WorldState.player_sheet.cash_cents)


func _on_money_changed(cash_cents: int) -> void:
	cash_label.text = "$%.2f" % (cash_cents / 100.0)


func _update_clock() -> void:
	clock_label.text = GameClock.time_string()


func _on_time_scale_changed(scale: float) -> void:
	if scale == 0.0:
		speed_label.text = "⏸ PAUSED  (space resumes, 1/2/3 speed)"
	else:
		speed_label.text = "▶ %dx speed  (space pauses, 1/2/3 speed)" % int(scale)


func _on_need_changed(need_id: String, value: float) -> void:
	if _bars.has(need_id):
		var bar: ProgressBar = _bars[need_id]
		bar.value = value
		# Flash toward red as a need bottoms out.
		var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
		if fill:
			fill.bg_color = fill.bg_color.lerp(Color(0.9, 0.15, 0.1), 0.0 if value > 25.0 else 0.6)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
