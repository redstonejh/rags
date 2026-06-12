class_name Interactable
extends Area2D
## Base class for anything the player (and later, NPCs) can use.
##
## This is The Sims' "smart object" pattern: objects advertise what they do
## (advertised_needs), and brains decide what to use. For M0 only the player
## interacts; NPC brains will read the same advertisements in M2.

@export var display_name: String = "Object"
@export var verb: String = "Use"
## need_id -> amount restored per use, e.g. {"hunger": 40.0}
@export var advertised_needs: Dictionary = {}


func prompt() -> String:
	return "[E] %s %s" % [verb, display_name]


## Override in subclasses for custom behavior; default just feeds needs.
func interact(actor: Node) -> void:
	if "needs" in actor and actor.needs is Needs:
		for need_id in advertised_needs:
			actor.needs.change(need_id, float(advertised_needs[need_id]))
		# Food is calories; the daily body tick turns calories into weight.
		var hunger := float(advertised_needs.get("hunger", 0.0))
		var sheet: CharacterSheet = WorldState.player_sheet
		if hunger > 0.0 and sheet != null and actor.needs == sheet.needs:
			sheet.flags["calories_today"] = int(sheet.flags.get("calories_today", 0)) + int(hunger * 25)
	EventBus.player_interacted.emit(self)
