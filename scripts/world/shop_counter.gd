class_name ShopCounter
extends Interactable
## Opens the shop UI. Stock is a list of item ids (infinite quantity in M3).

@export var stock: Array = []


func _init() -> void:
	verb = "Shop at"
	display_name = "the counter"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10), Vector2(-14, 10)])
	visual.color = Color(0.3, 0.5, 0.6)
	add_child(visual)


func interact(_actor: Node) -> void:
	EventBus.shop_opened.emit(stock)
