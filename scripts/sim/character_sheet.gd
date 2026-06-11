class_name CharacterSheet
extends RefCounted
## The player character's full sheet: identity, origin, D&D stats, traits,
## level/perks, money, and needs. Pure data + to_dict/from_dict.
##
## Forward-compatibility note (M2): NPCs get NPCRecord; the player record
## deliberately mirrors it so "Walk Away" (player becomes NPC) is a flag flip.

const STAT_IDS: Array = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const STAT_BASE := 8
const STAT_CAP := 15
const POINT_POOL := 27

var char_name: String = ""
var origin_id: String = ""
## Point-buy values BEFORE origin stat_mods (kept separate so the UI can re-derive).
var base_stats: Dictionary = {}
var trait_ids: Array = []
var appearance_tags: Array = []
var bio: String = ""

var level: int = 1
var xp: int = 0
var perk_ids: Array = []
var skills: Dictionary = {}

var cash_cents: int = 0
var needs: Needs = Needs.new()


func _init() -> void:
	for s in STAT_IDS:
		base_stats[s] = STAT_BASE


## Final stat = point-buy + origin mods + trait mods.
func get_stat(stat: String) -> int:
	var value: int = base_stats.get(stat, STAT_BASE)
	var origin := ContentDB.get_origin(origin_id)
	if origin:
		value += int(origin.stat_mods.get(stat, 0))
	for tid in trait_ids:
		var t := ContentDB.get_trait(tid)
		if t:
			value += int(t.stat_mods.get(stat, 0))
	return value


## D&D 5e-style point-buy cost for raising a stat from `from` to `from + 1`.
static func step_cost(from: int) -> int:
	return 1 if from < 13 else 2


static func points_spent(stats: Dictionary) -> int:
	var spent := 0
	for s in STAT_IDS:
		var v: int = stats.get(s, STAT_BASE)
		for step in range(STAT_BASE, v):
			spent += step_cost(step)
	return spent


## Trait budget: positive costs must be paid for by negative refunds.
## Valid when total <= 0. Free origin traits cost nothing.
func trait_budget() -> int:
	var origin := ContentDB.get_origin(origin_id)
	var free: Array = origin.free_traits if origin else []
	var bonus: int = origin.bonus_trait_points if origin else 0
	var total := -bonus
	for tid in trait_ids:
		if tid in free:
			continue
		var t := ContentDB.get_trait(tid)
		if t:
			total += t.point_cost
	return total


## Apply origin + traits to the needs bundle (decay multipliers stack).
func rebuild_needs_multipliers() -> void:
	var mults: Dictionary = {}
	for tid in trait_ids:
		var t := ContentDB.get_trait(tid)
		if t:
			for need_id in t.need_decay_multipliers:
				mults[need_id] = float(mults.get(need_id, 1.0)) * float(t.need_decay_multipliers[need_id])
	needs.decay_multipliers = mults


func add_cash(delta_cents: int) -> void:
	cash_cents += delta_cents
	EventBus.money_changed.emit(cash_cents)


func has_tag(tag: String) -> bool:
	var origin := ContentDB.get_origin(origin_id)
	if origin and tag in origin.tags:
		return true
	for tid in trait_ids:
		var t := ContentDB.get_trait(tid)
		if t and tag in t.tags:
			return true
	return false


func to_dict() -> Dictionary:
	return {
		"char_name": char_name,
		"origin_id": origin_id,
		"base_stats": base_stats.duplicate(),
		"trait_ids": trait_ids.duplicate(),
		"appearance_tags": appearance_tags.duplicate(),
		"bio": bio,
		"level": level,
		"xp": xp,
		"perk_ids": perk_ids.duplicate(),
		"skills": skills.duplicate(),
		"cash_cents": cash_cents,
		"needs": needs.to_dict(),
	}


static func from_dict(d: Dictionary) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.char_name = d.get("char_name", "Nobody")
	sheet.origin_id = d.get("origin_id", "off_the_bus")
	var saved_stats: Dictionary = d.get("base_stats", {})
	for s in STAT_IDS:
		sheet.base_stats[s] = int(saved_stats.get(s, STAT_BASE))
	sheet.trait_ids = d.get("trait_ids", []).duplicate()
	sheet.appearance_tags = d.get("appearance_tags", []).duplicate()
	sheet.bio = d.get("bio", "")
	sheet.level = int(d.get("level", 1))
	sheet.xp = int(d.get("xp", 0))
	sheet.perk_ids = d.get("perk_ids", []).duplicate()
	sheet.skills = d.get("skills", {}).duplicate()
	sheet.cash_cents = int(d.get("cash_cents", 0))
	sheet.needs = Needs.from_dict(d.get("needs", {}))
	return sheet
