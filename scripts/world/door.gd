class_name Door
extends Interactable
## A travel point: building entrances on the exterior, the exit inside.
## NPCs "use" doors abstractly (the sim just changes their location);
## the player triggers a real scene swap via EventBus.

var target_location_id: String = ""


func _init() -> void:
	verb = "Enter"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(-10, -14), Vector2(10, -14), Vector2(10, 14), Vector2(-10, 14)])
	marker.color = Color(0.32, 0.22, 0.14)
	add_child(marker)
	var knob := Polygon2D.new()
	knob.polygon = PackedVector2Array([
		Vector2(4, -2), Vector2(7, -2), Vector2(7, 2), Vector2(4, 2)])
	knob.color = Color(0.8, 0.7, 0.3)
	add_child(knob)


func interact(_actor: Node) -> void:
	EventBus.travel_requested.emit(target_location_id)
