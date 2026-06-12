class_name Door
extends Interactable
## A travel point: building entrances on the exterior, the exit inside.
## NPCs "use" doors abstractly (the sim just changes their location);
## the player triggers a real scene swap via EventBus.

const DOOR_TEXTURE_PATH := "res://assets/props/door.png"

var target_location_id: String = ""


func _init() -> void:
	verb = "Enter"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)
	var texture: Texture2D = load(DOOR_TEXTURE_PATH)
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = 1
		sprite.position = Vector2(0, -8)
		add_child(sprite)
	else:
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([
			Vector2(-10, -14), Vector2(10, -14), Vector2(10, 14), Vector2(-10, 14)])
		marker.color = Color(0.32, 0.22, 0.14)
		add_child(marker)


func interact(_actor: Node) -> void:
	EventBus.travel_requested.emit(target_location_id)
