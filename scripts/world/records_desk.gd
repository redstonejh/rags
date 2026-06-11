class_name RecordsDesk
extends Interactable
## The Hall of Records desk at Vantage Plaza — the boss fight of the
## "Getting Off the Street" Life Path. $40, two days of processing, and
## Window 3 is closed. Window 3 is always closed.

const ID_FEE_CENTS := 4000
const PROCESSING_DAYS := 2


func _init() -> void:
	verb = "Brave"
	display_name = "the Records Desk"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10)])
	visual.color = Color(0.5, 0.48, 0.4)
	add_child(visual)


func interact(_actor: Node) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet.flags.get("has_id", false):
		EventBus.toast.emit("You already have ID. The clerk seems disappointed.")
		return
	if sheet.flags.has("id_ready_day"):
		var ready: int = sheet.flags["id_ready_day"]
		if GameClock.day >= ready:
			sheet.flags["has_id"] = true
			sheet.flags.erase("id_ready_day")
			EventBus.toast.emit("You exist now, officially. The laminate is still warm.")
			EventBus.path_updated.emit()
		else:
			EventBus.toast.emit("Processing. Come back day %d. Window 3 is closed." % ready)
		return
	if sheet.cash_cents < ID_FEE_CENTS:
		EventBus.toast.emit("ID replacement costs $40. The clerk gestures at a sign saying so.")
		return
	sheet.add_cash(-ID_FEE_CENTS)
	sheet.flags["id_ready_day"] = GameClock.day + PROCESSING_DAYS
	GameClock.skip_minutes(90) # the line. oh, the line.
	EventBus.toast.emit("Forms filed. 90 minutes of your life, gone. Ready in %d days." % PROCESSING_DAYS)
	EventBus.path_updated.emit()
