class_name ItemDef
extends Resource
## An item definition. Runtime item state (durability, location) lives in
## records — definitions are read-only and shared.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var value_cents: int = 0
## Needs restored when consumed/used, e.g. {"hunger": 35.0}. Empty = not usable.
@export var need_effects: Dictionary = {}
## "consumable", "clothing", "weapon", "tool", "valuable", "disguise", ...
@export var tags: Array = []
## For clothing: the status the outfit projects (0 hoodie .. 3 great suit).
## Landlords, bouncers, and interviewers read it at a glance.
@export var status_tier: int = 0
