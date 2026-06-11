class_name BarCounter
extends Interactable
## The Rusty Anchor's bar. A drink is fun, social, and a small bad decision.

const DRINK_CENTS := 800


func _init() -> void:
	verb = "Drink at"
	display_name = "the bar ($8)"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10)])
	visual.color = Color(0.45, 0.3, 0.2)
	add_child(visual)


func interact(_actor: Node) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet.cash_cents < DRINK_CENTS:
		EventBus.toast.emit("The bartender's look says: not on credit.")
		return
	sheet.add_cash(-DRINK_CENTS)
	GameClock.skip_minutes(30)
	sheet.needs.change("fun", 22.0)
	sheet.needs.change("social", 18.0)
	sheet.needs.change("energy", -5.0)
	EventBus.toast.emit("One drink. Possibly two. The jukebox only plays 1974.")
