extends CanvasLayer
## Lightweight presentation layer for survival-loop actions: work shifts,
## sleep, hygiene/fun amenities, and eating. The sim still happens in the
## source systems; this only gives time skips and consumables a visible beat.

const COLORS := {
	"work": Color(0.95, 0.68, 0.25, 0.34),
	"sleep": Color(0.12, 0.16, 0.35, 0.58),
	"eat": Color(0.36, 0.55, 0.2, 0.38),
	"shower": Color(0.18, 0.55, 0.65, 0.34),
	"fun": Color(0.45, 0.28, 0.58, 0.34),
}
const DEFAULT_COLOR := Color(0.2, 0.2, 0.22, 0.36)

var _root: Control
var _wash: ColorRect
var _title: Label
var _detail: Label
var _tween: Tween = null


func _ready() -> void:
	layer = 15
	_build_ui()
	visible = false
	EventBus.survival_feedback.connect(_show)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_wash)

	var labels := VBoxContainer.new()
	labels.set_anchors_preset(Control.PRESET_CENTER)
	labels.position = Vector2(-260, -42)
	labels.custom_minimum_size = Vector2(520, 84)
	labels.add_theme_constant_override("separation", 4)
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(labels)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.76))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	labels.add_child(_title)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 14)
	_detail.add_theme_color_override("font_color", Color(0.86, 0.84, 0.76))
	_detail.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_detail.add_theme_constant_override("shadow_offset_x", 1)
	_detail.add_theme_constant_override("shadow_offset_y", 1)
	labels.add_child(_detail)


func _show(kind: String, title: String, detail: String) -> void:
	set_meta("survival_feedback_count", int(get_meta("survival_feedback_count", 0)) + 1)
	set_meta("last_survival_kind", kind)
	set_meta("last_survival_title", title)
	set_meta("last_survival_detail", detail)
	_title.text = title
	_detail.text = detail
	_wash.color = COLORS.get(kind, DEFAULT_COLOR)
	visible = true
	_root.modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 1.0, 0.12)
	_tween.tween_interval(0.32)
	_tween.tween_property(_root, "modulate:a", 0.0, 0.38)
	_tween.tween_callback(func() -> void: visible = false)
