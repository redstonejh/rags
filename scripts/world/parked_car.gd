class_name ParkedCar
extends Interactable
## The flagship gamble: you don't know who's in the car until you try the
## door. Empty: it's $150-300 at the chop shop and a Grand Theft Auto case.
## Occupied: a Confrontation with someone whose stats you may have badly
## misjudged. This is the whole Reality Check system in one prop.

const CHOP_MIN_CENTS := 15000
const CHOP_MAX_CENTS := 30000
const OCCUPIED_CHANCE := 0.3
const CAR_TEXTURE_PATH := "res://assets/props/parked_car.png"


func _init() -> void:
	verb = "Jack"
	display_name = "the parked car"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 30)
	shape.shape = rect
	add_child(shape)
	var color = [Color(0.75, 0.32, 0.32), Color(0.32, 0.42, 0.72),
			Color(0.8, 0.8, 0.82), Color(0.36, 0.55, 0.36)].pick_random()
	var texture: Texture2D = load(CAR_TEXTURE_PATH)
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = 1
		sprite.modulate = color
		add_child(sprite)
	else:
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-24, -10), Vector2(24, -10), Vector2(24, 10), Vector2(-24, 10)])
		body.color = color
		add_child(body)


func interact(_actor: Node) -> void:
	if randf() < OCCUPIED_CHANCE:
		var occupant := _pick_occupant()
		if occupant != null:
			EventBus.confrontation_started.emit({
				"kind": "carjack", "npc_id": occupant.id,
				"text": "The door opens and %s gets out of it. All of them." % occupant.display_name,
			})
			return
	var loot := randi_range(CHOP_MIN_CENTS, CHOP_MAX_CENTS)
	WorldState.player_sheet.dirty_cents += loot
	CrimeSystem.commit("car_theft", "exterior", null, global_position)
	EventBus.toast.emit("Empty. Twenty minutes later it's $%.2f at the chop shop. Beater rates." % (loot / 100.0))
	queue_free()


func _pick_occupant() -> NPCRecord:
	var pool: Array = []
	for npc in WorldState.npcs.values():
		if npc.alive and npc.current_activity != "sleeping":
			pool.append(npc)
	return pool.pick_random() if not pool.is_empty() else null
