class_name PerkDef
extends Resource
## A perk — picked every 2 character levels. Perks prefer new verbs over
## numbers. `origin_line` non-empty = exclusive to that origin's perk line.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var min_level: int = 2
## "" = general pool; otherwise an origin id (exclusive perk line).
@export var origin_line: String = ""
@export var requires_perks: Array = []
## Mechanic tags read by subsystems: "people_reader", "silver_tongue", ...
@export var tags: Array = []
