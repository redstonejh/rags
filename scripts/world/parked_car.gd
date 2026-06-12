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
const CAR_COLORS := [
	Color(0.75, 0.32, 0.32),
	Color(0.32, 0.42, 0.72),
	Color(0.8, 0.8, 0.82),
	Color(0.36, 0.55, 0.36),
]

var occupied_chance := OCCUPIED_CHANCE
var _paint_nodes: Array = []


func _init() -> void:
	verb = "Jack"
	display_name = "the parked car"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 30)
	shape.shape = rect
	add_child(shape)
	var color: Color = CAR_COLORS[0]
	var texture: Texture2D = load(CAR_TEXTURE_PATH)
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = 1
		sprite.modulate = color
		_paint_nodes.append(sprite)
		add_child(sprite)
	else:
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-24, -10), Vector2(24, -10), Vector2(24, 10), Vector2(-24, 10)])
		body.color = color
		_paint_nodes.append(body)
		add_child(body)


func _ready() -> void:
	_apply_stable_color()


func _apply_stable_color() -> void:
	var key := "%d:%d" % [roundi(global_position.x), roundi(global_position.y)]
	var color: Color = CAR_COLORS[absi(hash(key)) % CAR_COLORS.size()]
	for node in _paint_nodes:
		if node is Sprite2D:
			node.modulate = color
		elif node is Polygon2D:
			node.color = color


func interact(_actor: Node) -> void:
	if CrimeSystem.roll_chance(occupied_chance):
		var occupant := _pick_occupant()
		if occupant != null:
			EventBus.confrontation_started.emit({
				"kind": "carjack", "npc_id": occupant.id,
				"text": "The door opens and %s gets out of it. All of them." % occupant.display_name,
			})
			return
	var loot := CrimeSystem.random_int(CHOP_MIN_CENTS, CHOP_MAX_CENTS)
	WorldState.player_sheet.add_dirty_cash(loot)
	var case := CrimeSystem.commit_car_theft("exterior", global_position)
	var alarm_text := " The plates are hot; wanted stars are already moving." \
			if case.is_active_warrant() else ""
	EventBus.toast.emit("Empty. Twenty minutes later it's $%.2f at the chop shop. Beater rates.%s" % [
			loot / 100.0, alarm_text])
	EventBus.interact_target_changed.emit("")
	monitoring = false
	monitorable = false
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()


func _pick_occupant() -> NPCRecord:
	var pool: Array = []
	for npc in WorldState.npcs.values():
		if npc.alive and npc.current_activity != "sleeping":
			pool.append(npc)
	if pool.is_empty():
		return null
	pool.sort_custom(func(a: NPCRecord, b: NPCRecord) -> bool: return a.id < b.id)
	return pool[CrimeSystem.random_int(0, pool.size() - 1)]
