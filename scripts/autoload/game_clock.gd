extends Node
## The game clock — the single driver of ALL simulation.
##
## Nothing in the game simulates in _process(delta) except this node, which
## converts real seconds into discrete game-minute ticks. Everything else
## (needs decay, NPC schedules, economy) advances by listening to
## EventBus.minute_passed / hour_passed / day_passed. Fast-forward just means
## more ticks per real second — the simulation math never changes.

const MINUTES_PER_DAY := 1440
const SPEEDS: Array[float] = [1.0, 4.0, 12.0] # keys 1 / 2 / 3

## At 1x speed: 1 real second = 1 game minute (a full day ≈ 24 real minutes).
var time_scale: float = 1.0
var paused: bool = false

## Total game minutes elapsed since the start of day 1, 00:00.
## Starts at day 1, 7:00 AM.
var total_minutes: int = MINUTES_PER_DAY + 7 * 60

var _accumulator: float = 0.0

var day: int:
	get: return total_minutes / MINUTES_PER_DAY
var hour: int:
	get: return (total_minutes % MINUTES_PER_DAY) / 60
var minute: int:
	get: return total_minutes % 60


func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta * time_scale
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		_advance_minute()


func _advance_minute() -> void:
	total_minutes += 1
	EventBus.minute_passed.emit(total_minutes)
	if minute == 0:
		EventBus.hour_passed.emit(hour)
		if hour == 0:
			EventBus.day_passed.emit(day)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_pause"):
		paused = not paused
		EventBus.time_scale_changed.emit(0.0 if paused else time_scale)
	for i in SPEEDS.size():
		if event.is_action_pressed("time_speed_%d" % (i + 1)):
			time_scale = SPEEDS[i]
			paused = false
			EventBus.time_scale_changed.emit(time_scale)


## Fast-forward time synchronously (sleep, work shifts, queues). Fires every
## minute signal along the way so the whole simulation stays consistent —
## NPCs keep their schedules, needs decay, bills come due mid-skip.
func skip_minutes(minutes: int) -> void:
	for _i in maxi(minutes, 0):
		_advance_minute()


## "Day 3, 7:05 AM" — used by the HUD and (later) save metadata.
func time_string() -> String:
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	var ampm := "AM" if hour < 12 else "PM"
	return "Day %d, %d:%02d %s" % [day, h12, minute, ampm]


func to_dict() -> Dictionary:
	return {"total_minutes": total_minutes, "time_scale": time_scale}


func load_dict(d: Dictionary) -> void:
	total_minutes = int(d.get("total_minutes", MINUTES_PER_DAY + 7 * 60))
	time_scale = float(d.get("time_scale", 1.0))
