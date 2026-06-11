extends CanvasModulate
## Tints the world canvas by time of day. The HUD lives on a CanvasLayer,
## which is a separate canvas, so UI is unaffected.

var _gradient := Gradient.new()


func _ready() -> void:
	# Offsets are fraction-of-day (0.0 = midnight). Colors multiply the scene.
	var night := Color(0.17, 0.19, 0.38)
	var dawn := Color(1.0, 0.78, 0.62)
	var day := Color(1, 1, 1)
	var dusk := Color(1.0, 0.6, 0.42)
	_gradient.offsets = PackedFloat32Array([0.0, 0.20, 0.28, 0.38, 0.70, 0.80, 0.88, 1.0])
	_gradient.colors = PackedColorArray([night, night, dawn, day, day, dusk, night, night])

	EventBus.minute_passed.connect(_on_minute_passed)
	_on_minute_passed(GameClock.total_minutes)


func _on_minute_passed(total_minutes: int) -> void:
	var day_fraction := float(total_minutes % GameClock.MINUTES_PER_DAY) \
			/ float(GameClock.MINUTES_PER_DAY)
	color = _gradient.sample(day_fraction)
