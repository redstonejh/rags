class_name OriginDef
extends Resource
## An origin story — the "class" of RAGS. All start you poor; this defines
## HOW poor, what your past life gave you, and what's still chasing you.
##
## Origin-specific mechanics activate via tags read by generic subsystems
## (e.g. "addiction", "no_papers", "parole") — never `if origin == x` in code.

@export var id: String = ""
@export var display_name: String = ""
## The flavor title, e.g. "The Golden Parachute That Didn't Open"
@export var title: String = ""
@export_multiline var blurb: String = ""
@export_range(1, 5) var difficulty: int = 1

@export var starting_cash_cents: int = 0
@export var starting_items: Array = []        # item ids
@export var starting_location_id: String = ""
## Housing id ("" = homeless). Rent comes due Mondays — see EconomySystem.
@export var starting_housing_id: String = ""
## Initial sheet flags, e.g. {"rent_prepaid_weeks": 4} for the exec's
## one-month head start.
@export var starting_flags: Dictionary = {}

## Flat stat adjustments applied AFTER point-buy, e.g. {"CHA": 2, "CON": -1}
@export var stat_mods: Dictionary = {}
## Weighting used by the Coherence Engine when randomly allocating stats,
## e.g. {"CHA": 3.0, "INT": 2.0} — higher = this origin tends toward it.
@export var stat_bias: Dictionary = {}
## Starting skill levels, e.g. {"streetwise": 4, "persuasion": 2}
@export var skill_seeds: Dictionary = {}

## Trait ids granted for free (don't cost points, can't be removed).
@export var free_traits: Array = []
## Trait ids this origin cannot take.
@export var locked_traits: Array = []
## Extra trait points granted (usually 0 — origins are balanced internally).
@export var bonus_trait_points: int = 0

## Mechanic tags read by subsystems: "addiction", "no_papers", "parole",
## "rival", "debt", "champagne_taste", "street_family", "luck", ...
@export var tags: Array = []
