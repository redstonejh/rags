class_name NPCAgent
extends CharacterBody2D
## The visible puppet for an embodied NPCRecord. Cosmetic in M2: walks
## where the abstract sim says the person is going, idles believably at
## their location. The record is authoritative — if the timer says they
## arrived, the puppet despawns regardless.

const WALK_SPEED := 120.0
const ANIM_FPS := 8.0
const FRAME_IDLE := 1
const DIR_DOWN := 0
const DIR_RIGHT := 1
const DIR_UP := 2
const DIR_LEFT := 3
const REACTION_TEXT := "!"
const TARGET_REACTION_TEXT := "!!"

var record: NPCRecord
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait := 0.0
var _anim_time := 0.0
var _facing_dir := DIR_DOWN
var _base_name := ""

@onready var body_sprite: Sprite2D = $BodySprite
@onready var outfit_sprite: Sprite2D = $OutfitSprite
@onready var name_label: Label = $NameLabel
@onready var nav: NavigationAgent2D = $NavigationAgent2D


func setup(npc: NPCRecord) -> void:
	record = npc


func _ready() -> void:
	var arch := record.archetype()
	if arch:
		outfit_sprite.modulate = arch.color
	_base_name = record.display_name.get_slice(" ", 0)
	name_label.text = _base_name
	_wander_target = global_position
	add_child(NPCInteractable.new(record))


func _physics_process(delta: float) -> void:
	if record == null:
		return
	if _update_reaction_cue():
		velocity = Vector2.ZERO
		_update_sprite_animation(velocity, delta)
		return
	if record.traveling:
		_walk_toward(record.travel_to_pos, delta)
	else:
		_idle_wander(delta)


func _update_reaction_cue() -> bool:
	var until_min := int(record.flags.get("reacting_until_min", -1))
	if until_min < GameClock.total_minutes:
		if name_label.text in [REACTION_TEXT, TARGET_REACTION_TEXT]:
			name_label.text = _base_name
		return false
	name_label.text = _reaction_text()
	var target_id := str(record.flags.get("reaction_target_id", ""))
	if target_id == "player" and SimEngine.player_node != null \
			and is_instance_valid(SimEngine.player_node):
		_facing_dir = _direction_from_velocity(
				global_position.direction_to(SimEngine.player_node.global_position))
		return true
	var target: NPCRecord = WorldState.npcs.get(target_id)
	if target != null and target.agent != null and is_instance_valid(target.agent):
		_facing_dir = _direction_from_velocity(global_position.direction_to(target.agent.global_position))
	return true


func _reaction_text() -> String:
	return TARGET_REACTION_TEXT if record.flags.get("reaction_kind", "") == "called_out" else REACTION_TEXT


func _walk_toward(target: Vector2, _delta: float) -> void:
	if nav.target_position.distance_to(target) > 24.0:
		nav.target_position = target
	if nav.is_navigation_finished():
		velocity = Vector2.ZERO
		_update_sprite_animation(velocity, _delta)
		return
	var next := nav.get_next_path_position()
	velocity = global_position.direction_to(next) * WALK_SPEED
	move_and_slide()
	_update_sprite_animation(velocity, _delta)


func _idle_wander(delta: float) -> void:
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		_wander_wait = randf_range(2.0, 7.0)
		var anchor := global_position
		_wander_target = anchor + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	if global_position.distance_to(_wander_target) > 8.0 \
			and record.current_activity not in ["sleeping", "working"]:
		velocity = global_position.direction_to(_wander_target) * WALK_SPEED * 0.35
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	_update_sprite_animation(velocity, delta)


func _update_sprite_animation(move_velocity: Vector2, delta: float) -> void:
	var moving := move_velocity.length_squared() > 1.0
	if moving:
		_facing_dir = _direction_from_velocity(move_velocity)
		_anim_time += delta
	else:
		_anim_time = 0.0
	var frame := int(floor(_anim_time * ANIM_FPS)) % 4 if moving else FRAME_IDLE
	var coords := Vector2i(frame, _facing_dir)
	body_sprite.frame_coords = coords
	outfit_sprite.frame_coords = coords


func _direction_from_velocity(move_velocity: Vector2) -> int:
	if absf(move_velocity.x) > absf(move_velocity.y):
		return DIR_RIGHT if move_velocity.x > 0.0 else DIR_LEFT
	return DIR_DOWN if move_velocity.y > 0.0 else DIR_UP
