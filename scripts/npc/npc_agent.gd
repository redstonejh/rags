class_name NPCAgent
extends CharacterBody2D
## The visible puppet for an embodied NPCRecord. Cosmetic in M2: walks
## where the abstract sim says the person is going, idles believably at
## their location. The record is authoritative — if the timer says they
## arrived, the puppet despawns regardless.

const WALK_SPEED := 120.0

var record: NPCRecord
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait := 0.0

@onready var outfit_sprite: Sprite2D = $OutfitSprite
@onready var name_label: Label = $NameLabel
@onready var nav: NavigationAgent2D = $NavigationAgent2D


func setup(npc: NPCRecord) -> void:
	record = npc


func _ready() -> void:
	var arch := record.archetype()
	if arch:
		outfit_sprite.modulate = arch.color
	name_label.text = record.display_name.get_slice(" ", 0)
	_wander_target = global_position
	add_child(NPCInteractable.new(record))


func _physics_process(delta: float) -> void:
	if record == null:
		return
	if record.traveling:
		_walk_toward(record.travel_to_pos, delta)
	else:
		_idle_wander(delta)


func _walk_toward(target: Vector2, _delta: float) -> void:
	if nav.target_position.distance_to(target) > 24.0:
		nav.target_position = target
	if nav.is_navigation_finished():
		velocity = Vector2.ZERO
		return
	var next := nav.get_next_path_position()
	velocity = global_position.direction_to(next) * WALK_SPEED
	move_and_slide()


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
