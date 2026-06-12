class_name SubstanceDef
extends Resource
## A drug, simulated honestly: REAL effects vs PERCEIVED confidence. Every
## substance widens the perceived-vs-real odds gap its own way — that gap is
## bar fights you can't win. Tolerance shrinks the high; addiction grows the
## bill; the body keeps the receipts.

@export var id: String = ""
@export var display_name: String = ""
@export var price_cents: int = 0
## Real need effects per use (before tolerance), e.g. {"energy": 60.0}.
@export var need_effects: Dictionary = {}
## Displayed-odds confidence multiplier while active (1.0 = honest).
@export var confidence_mult: float = 1.0
## Minutes the high (and its confidence lie) lasts.
@export var duration_minutes: int = 90
@export var addiction_per_use: float = 0.02
@export var tolerance_per_use: float = 0.01
## Base overdose chance per use (scaled up by addiction).
@export var overdose_chance: float = 0.0
## Lethal-with-alcohol flag (xanax: the game tracks this).
@export var deadly_with_alcohol: bool = false
## Chance per use of losing a tooth (meth) — teeth are tracked.
@export var tooth_risk: float = 0.0
@export_multiline var blurb: String = ""
