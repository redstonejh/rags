class_name ArchetypeDef
extends Resource
## An NPC archetype: who they are, where they work, and the shape of their
## day. Individual NPCs get jitter (schedule offset, personality, stats) on
## top so no two are identical.

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## How many of these the world generator creates.
@export var count: int = 0
## "" = no workplace.
@export var workplace_id: String = ""
## Stat allocation bias for the Coherence Engine, e.g. {"STR": 2.0}.
@export var stat_bias: Dictionary = {}
## Daily schedule blocks, evaluated in order. Each: {"h": start_hour,
## "loc": location_id | "home" | "work", "activity": String}.
@export var schedule: Array = []
## Behavior tags: "cop", "criminal_leaning", ...
@export var tags: Array = []
