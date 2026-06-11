class_name TraitDef
extends Resource
## A character trait, Project Zomboid style. Positive traits cost points,
## negative traits refund them; the build must balance to <= 0.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Positive = costs points (good trait). Negative = refunds points (bad trait).
@export var point_cost: int = 0

## Need decay multipliers, e.g. {"energy": 1.3} for Insomniac.
@export var need_decay_multipliers: Dictionary = {}
## Flat stat adjustments, e.g. {"STR": 1}.
@export var stat_mods: Dictionary = {}
## Mechanic tags read by subsystems: "iron_stomach", "forgettable_face", ...
@export var tags: Array = []
@export var conflicts_with: Array = []

## Coherence Engine hints: appearance/persona tags this trait correlates
## with, e.g. ["bookish"] for Fast Learner — used to pick coherent random builds.
@export var coherence_tags: Array = []
