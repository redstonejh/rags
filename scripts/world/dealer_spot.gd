class_name DealerSpot
extends Interactable
## A guy who knows a guy, behind Site 9. M7: the full catalog — every
## substance with a street price, sold through the same shop UI. Cash only,
## obviously; the dirty kind preferred.

const MENU := ["meth", "weed_bag", "heroin_dose", "cocaine_gram",
		"xanax_pill", "lsd_tab", "oxy_pill"]


func _init() -> void:
	verb = "Talk to"
	display_name = "a guy"
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
	EventBus.toast.emit("\"What do you need?\" He asks it like a pharmacist who lost a bet.")
	EventBus.shop_opened.emit(MENU)
