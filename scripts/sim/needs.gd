class_name Needs
extends RefCounted
## A bundle of 0–100 need bars that decay per game-minute tick.
##
## Pure data — used identically by the player and (from M2 on) every NPCRecord.
## Decay rates are "points lost per game minute"; trait/origin multipliers
## plug in via decay_multipliers (e.g. an Insomniac gets {"energy": 1.3}).

signal changed(need_id: String, value: float)

## Baseline decay per game minute. Hunger: full → empty in ~14 game hours.
## Energy: full → empty in ~20 game hours.
const BASE_DECAY := {
	"hunger": 0.12,
	"energy": 0.085,
	"hygiene": 0.055,
	"fun": 0.07,
	"social": 0.05,
}

## Extra need bars only some characters have (origin tags add them),
## e.g. "craving" for addiction origins. id -> decay per minute.
const OPTIONAL_DECAY := {
	"craving": 0.07,
}

var values: Dictionary = {}
var decay_multipliers: Dictionary = {}


func _init() -> void:
	for id in BASE_DECAY:
		values[id] = 100.0


func add_optional(need_id: String) -> void:
	if not values.has(need_id) and OPTIONAL_DECAY.has(need_id):
		values[need_id] = 100.0


## Called once per game-minute tick by whoever owns this bundle.
func apply_minute() -> void:
	for id in values:
		var base: float = BASE_DECAY.get(id, OPTIONAL_DECAY.get(id, 0.0))
		var rate: float = base * float(decay_multipliers.get(id, 1.0))
		change(id, -rate)


func change(need_id: String, amount: float) -> void:
	if not values.has(need_id):
		return
	var new_value: float = clampf(values[need_id] + amount, 0.0, 100.0)
	if not is_equal_approx(new_value, values[need_id]):
		values[need_id] = new_value
		changed.emit(need_id, new_value)


func get_value(need_id: String) -> float:
	return values.get(need_id, 0.0)


func to_dict() -> Dictionary:
	return {"values": values.duplicate(), "decay_multipliers": decay_multipliers.duplicate()}


static func from_dict(d: Dictionary) -> Needs:
	var n := Needs.new()
	var saved: Dictionary = d.get("values", {})
	for id in saved:
		n.values[id] = float(saved[id])
	n.decay_multipliers = d.get("decay_multipliers", {}).duplicate()
	return n
