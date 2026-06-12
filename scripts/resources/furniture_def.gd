class_name FurnitureDef
extends Resource
## A thing you own that makes home feel like one. kind "bed"/"tv" upgrades
## the matching amenity's quality; everything contributes comfort -> Mood.
## A $30 mattress and a $3,000 bed are different lives.

@export var id: String = ""
@export var display_name: String = ""
@export var cost_cents: int = 0
## "bed", "tv", or "deco" (comfort only).
@export var kind: String = "deco"
@export var quality: float = 1.0
@export var comfort: float = 1.0
@export_multiline var blurb: String = ""
