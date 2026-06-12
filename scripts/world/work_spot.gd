class_name WorkSpot
extends Interactable
## "Work your shift" — the time-skip work loop. Standing here during your
## shift fast-forwards to clocking-out time; the ShiftSystem pays you and
## rolls dilemma events along the way.

@export var workplace_id: String = ""

const WORK_SPOT_TEXTURE_PATH := "res://assets/props/work_spot.png"


func _init() -> void:
	verb = "Work"
	display_name = "your shift"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	if not _add_prop_sprite():
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10)])
		visual.color = Color(0.35, 0.3, 0.25)
		add_child(visual)


func _add_prop_sprite() -> bool:
	var texture: Texture2D = load(WORK_SPOT_TEXTURE_PATH)
	if texture == null:
		return false
	var sprite := Sprite2D.new()
	sprite.name = "PropSprite"
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.position = Vector2(0, -3)
	add_child(sprite)
	return true


func interact(_actor: Node) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		EventBus.toast.emit("There's no one on the schedule. Exist first, clock in later.")
		return
	var job := sheet.job()
	if job == null:
		EventBus.toast.emit("You don't work here. (Get hired via your phone.)")
		return
	if job.workplace_id != workplace_id:
		EventBus.toast.emit("Your job is at %s." % Locations.display_name(job.workplace_id))
		return
	var weekday := GameClock.day % 7
	if weekday not in job.work_days:
		EventBus.toast.emit("Day off. Even %s rests." % job.display_name)
		return
	var now_min := GameClock.total_minutes % GameClock.MINUTES_PER_DAY
	var start := job.shift_start_hour * 60
	var end := start + job.shift_len_hours * 60
	if now_min < start - 60:
		EventBus.toast.emit("Shift starts at %d:00. Loitering builds no career." % job.shift_start_hour)
		return
	if now_min >= end:
		EventBus.toast.emit("Shift's over. The %s forgives, once." % job.display_name)
		return
	var late_by := maxi(0, now_min - start)
	var minutes_left := end - now_min
	EventBus.toast.emit("Clocking in: %s. %s until %s.%s" % [
		job.display_name,
		_duration_label(minutes_left),
		_time_label(end),
		" Late by %s." % _duration_label(late_by) if late_by > 0 else ""])
	EventBus.survival_feedback.emit("work", job.display_name,
			"%s at %s. Clock-out: %s. Gross pay: $%.2f." % [
				_duration_label(minutes_left),
				Locations.display_name(job.workplace_id),
				_time_label(end),
				job.wage_cents_per_shift / 100.0])
	EventBus.shift_started.emit(job, late_by)
	GameClock.skip_minutes(minutes_left)
	EventBus.shift_finished.emit(job, late_by)


func _duration_label(minutes: int) -> String:
	var clamped := maxi(minutes, 0)
	var hours := clamped / 60
	var mins := clamped % 60
	if hours > 0 and mins > 0:
		return "%dh %02dm" % [hours, mins]
	if hours > 0:
		return "%dh" % hours
	return "%dm" % mins


func _time_label(day_minutes: int) -> String:
	var wrapped := posmod(day_minutes, GameClock.MINUTES_PER_DAY)
	var hour := wrapped / 60
	var minute := wrapped % 60
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute, "AM" if hour < 12 else "PM"]
