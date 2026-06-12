class_name Player
extends CharacterBody2D
## Player movement, needs ownership, and interaction targeting.

const WALK_SPEED := 150.0
## Below these thresholds you slow down — being starving/exhausted is physical.
const LOW_NEED_THRESHOLD := 18.0
const LOW_NEED_SPEED_MULT := 0.55
const CLICK_INTERACT_DISTANCE := 34.0

## Owned by the CharacterSheet in WorldState — the player node is a view.
var needs: Needs

var _interact_target: Interactable = null
var _click_move_active := false
var _click_interact_target: Interactable = null

@onready var interact_area: Area2D = $InteractArea
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D


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
	var speed := _current_speed()
	if input.length_squared() > 0.0:
		_cancel_click_move()
		velocity = input * speed
	elif _click_move_active:
		velocity = _click_move_velocity(speed)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_interact_target()
	_try_click_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _interact_target != null:
		_interact_target.interact(self)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not GameClock.paused:
		var target := get_global_mouse_position()
		var interactable := _interactable_at(target)
		set_move_target(interactable.global_position if interactable else target, interactable)
		get_viewport().set_input_as_handled()


func set_move_target(target: Vector2, interact_after: Interactable = null) -> void:
	_click_move_active = true
	_click_interact_target = interact_after
	nav_agent.target_position = target


func has_click_target() -> bool:
	return _click_move_active


func _on_minute_passed(_total: int) -> void:
	WorldState.player_sheet.tick_minute()


func _on_need_changed(need_id: String, value: float) -> void:
	EventBus.player_need_changed.emit(need_id, value)


func _emit_all_needs() -> void:
	for id in needs.values:
		EventBus.player_need_changed.emit(id, needs.values[id])


func _current_speed() -> float:
	var speed := WALK_SPEED
	if needs.get_value("energy") < LOW_NEED_THRESHOLD \
			or needs.get_value("hunger") < LOW_NEED_THRESHOLD:
		speed *= LOW_NEED_SPEED_MULT
	# The beater: fast-travel-with-steering, exterior only.
	if WorldState.player_location_id == "exterior" \
			and WorldState.player_sheet.flags.get("has_car", false):
		speed *= 1.8
	return speed


func _click_move_velocity(speed: float) -> Vector2:
	if nav_agent.is_navigation_finished():
		_click_move_active = false
		return Vector2.ZERO
	var next_pos := nav_agent.get_next_path_position()
	var to_next := next_pos - global_position
	if to_next.length_squared() < 4.0:
		return Vector2.ZERO
	return to_next.normalized() * speed


func _cancel_click_move() -> void:
	if not _click_move_active:
		return
	_click_move_active = false
	_click_interact_target = null
	nav_agent.target_position = global_position


func _try_click_interaction() -> void:
	if _click_interact_target == null:
		return
	if global_position.distance_to(_click_interact_target.global_position) > CLICK_INTERACT_DISTANCE:
		return
	var target := _click_interact_target
	_click_move_active = false
	_click_interact_target = null
	target.interact(self)


func _interactable_at(point: Vector2) -> Interactable:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_point(params, 16)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Interactable:
			return collider
	return null


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
