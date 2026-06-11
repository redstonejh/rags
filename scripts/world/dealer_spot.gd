class_name DealerSpot
extends Interactable
## A guy who knows a guy, behind Site 9. Sells exactly one product.
## Cash only, obviously. (Full drug economy lands in M7; this exists in M3
## because the Tweaker origin's craving needs an answer in the world.)

const PRICE_CENTS := 2000


func _init() -> void:
	verb = "Talk to"
	display_name = "a guy ($20)"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-8, -13), Vector2(8, -13), Vector2(8, 13), Vector2(-8, 13)])
	visual.color = Color(0.25, 0.28, 0.25)
	add_child(visual)


func interact(_actor: Node) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var total := sheet.cash_cents + sheet.dirty_cents
	if total < PRICE_CENTS:
		EventBus.toast.emit("\"Come back with twenty.\" He says it almost kindly.")
		return
	# Dirty money spends fine on the street.
	var from_dirty: int = mini(sheet.dirty_cents, PRICE_CENTS)
	sheet.dirty_cents -= from_dirty
	if PRICE_CENTS - from_dirty > 0:
		sheet.add_cash(-(PRICE_CENTS - from_dirty))
	sheet.inventory.append("meth")
	EventBus.toast.emit("The handshake had something in it. Inventory updated.")
