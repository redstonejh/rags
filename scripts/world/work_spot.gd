class_name WorkSpot
extends Interactable
## "Work your shift" — the time-skip work loop. Standing here during your
## shift fast-forwards to clocking-out time; the ShiftSystem pays you and
## rolls dilemma events along the way.

@export var workplace_id: String = ""


func _init() -> void:
	verb = "Work"
	display_name = "your shift"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10)])
	visual.color = Color(0.35, 0.3, 0.25)
	add_child(visual)


func interact(_actor: Node) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
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
	var minutes_left := end - maxi(now_min, start)
	EventBus.shift_started.emit(job, late_by)
	GameClock.skip_minutes(minutes_left)
	EventBus.shift_finished.emit(job, late_by)
