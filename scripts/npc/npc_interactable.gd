class_name NPCInteractable
extends Interactable
## The "talk to me" zone every embodied NPC carries. Interacting opens the
## dialogue UI via EventBus — the agent is just the doorbell.

var record: NPCRecord


func _init(npc: NPCRecord = null) -> void:
	record = npc
	verb = "Talk to"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)


func prompt() -> String:
	return "[E] Talk to %s" % (record.display_name if record else "them")


func interact(_actor: Node) -> void:
	if record != null:
		EventBus.dialogue_requested.emit(record.id)
