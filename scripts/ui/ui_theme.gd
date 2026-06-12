extends RefCounted
## Small runtime theme pass for gameplay UI. Most screens are built in code,
## so this styles controls as they appear instead of requiring a full editor
## Theme resource pass yet.

const PANEL_BG := Color(0.075, 0.071, 0.067, 0.96)
const PANEL_BORDER := Color(0.45, 0.39, 0.28, 1.0)
const BUTTON_BG := Color(0.18, 0.17, 0.15, 1.0)
const BUTTON_HOVER := Color(0.27, 0.24, 0.19, 1.0)
const BUTTON_PRESSED := Color(0.42, 0.22, 0.17, 1.0)
const TEXT := Color(0.9, 0.86, 0.74, 1.0)
const TEXT_DIM := Color(0.62, 0.6, 0.55, 1.0)


static func apply_tree(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		apply_control(root)
	for child in root.get_children():
		apply_tree(child)


static func apply_control(control: Control) -> void:
	if control.has_meta("rags_themed"):
		return
	control.set_meta("rags_themed", true)
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", _panel_style())
	elif control is Button:
		_style_button(control)
	elif control is TabContainer:
		control.add_theme_stylebox_override("panel", _panel_style())
	elif control is ScrollContainer:
		control.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.04, 0.045, 0.55), 4, 0))
	elif control is Label:
		if not control.has_theme_color_override("font_color"):
			control.add_theme_color_override("font_color", TEXT)


static func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _flat(BUTTON_BG, 4, 1, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", _flat(BUTTON_HOVER, 4, 1, PANEL_BORDER.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _flat(BUTTON_PRESSED, 4, 1, Color(0.7, 0.35, 0.25)))
	button.add_theme_stylebox_override("disabled", _flat(Color(0.08, 0.08, 0.08, 0.85), 4, 1, Color(0.2, 0.2, 0.2)))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.78))
	button.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.25))
	button.add_theme_constant_override("h_separation", 8)


static func _panel_style() -> StyleBoxFlat:
	var style := _flat(PANEL_BG, 6, 1, PANEL_BORDER)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func _flat(color: Color, radius: int, border: int = 0,
		border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border > 0:
		style.set_border_width_all(border)
		style.border_color = border_color
	return style
