class_name Player
extends CharacterBody2D
## Player movement, needs ownership, and interaction targeting.

const WALK_SPEED := 150.0
## Below these thresholds you slow down — being starving/exhausted is physical.
const LOW_NEED_THRESHOLD := 18.0
const LOW_NEED_SPEED_MULT := 0.55

## Owned by the CharacterSheet in WorldState — the player node is a view.
var needs: Needs

var _interact_target: Interactable = null

@onready var interact_area: Area2D = $InteractArea


func _ready() -> void:
	WorldState.ensure_player_sheet()
	needs = WorldState.player_sheet.needs
	EventBus.minute_passed.connect(_on_minute_passed)
	needs.changed.connect(_on_need_changed)
	# Deferred so the HUD (added after the player) is connected before the
	# initial values arrive.
	_emit_all_needs.call_deferred()


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := WALK_SPEED
	if needs.get_value("energy") < LOW_NEED_THRESHOLD \
			or needs.get_value("hunger") < LOW_NEED_THRESHOLD:
		speed *= LOW_NEED_SPEED_MULT
	# The beater: fast-travel-with-steering, exterior only.
	if WorldState.player_location_id == "exterior" \
			and WorldState.player_sheet.flags.get("has_car", false):
		speed *= 1.8
	velocity = input * speed
	move_and_slide()
	_update_interact_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _interact_target != null:
		_interact_target.interact(self)


func _on_minute_passed(_total: int) -> void:
	WorldState.player_sheet.tick_minute()


func _on_need_changed(need_id: String, value: float) -> void:
	EventBus.player_need_changed.emit(need_id, value)


func _emit_all_needs() -> void:
	for id in needs.values:
		EventBus.player_need_changed.emit(id, needs.values[id])


func _update_interact_target() -> void:
	var nearest: Interactable = null
	var nearest_dist := INF
	for area in interact_area.get_overlapping_areas():
		if area is Interactable:
			var dist := global_position.distance_squared_to(area.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = area
	if nearest != _interact_target:
		_interact_target = nearest
		EventBus.interact_target_changed.emit(nearest.prompt() if nearest else "")
