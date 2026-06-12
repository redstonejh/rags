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

var cash_cents: int = 0          # clean cash in pocket
var dirty_cents: int = 0         # crime money — banks and landlords won't touch it
var bank_cents: int = 0
var mickey_debt_cents: int = 0   # the loan shark's ledger
var needs: Needs = Needs.new()

var inventory: Array = []        # item ids (stackable duplicates allowed)
var job_id: String = ""
var shifts_worked: int = 0
var housing_id: String = ""      # "" = homeless
var rent_strikes: int = 0
var weight_kg: float = 75.0
var lives_lived: int = 1         # which life in this world this is
var alive: bool = true


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
	# Origin hooks: tags activate generic mechanics — never `if origin == x`.
	if has_tag("champagne_taste"):
		# Needs calibrated to a life you can no longer afford.
		mults["fun"] = float(mults.get("fun", 1.0)) * 1.6
		mults["social"] = float(mults.get("social", 1.0)) * 1.3
	if has_tag("addiction_meth"):
		needs.add_optional("craving")
	needs.decay_multipliers = mults
	# Papers: most people have ID; no_papers origins must earn one (Life Path).
	if not flags.has("has_id"):
		flags["has_id"] = not has_tag("no_papers")


var flags: Dictionary = {}


## Mood is the master stat: the average of needs, dragged by withdrawal,
## debt stress, and homelessness. 0-100.
func mood() -> float:
	var total := 0.0
	for id in needs.values:
		total += needs.values[id]
	var m := total / maxf(needs.values.size(), 1.0)
	if needs.values.has("craving") and needs.values["craving"] < 30.0:
		m -= 20.0 # withdrawal
	if mickey_debt_cents > 0:
		m -= 5.0
	if housing_id == "":
		m -= 10.0
	return clampf(m, 0.0, 100.0)


func job() -> JobDef:
	return ContentDB.get_job(job_id) if job_id != "" else null


func count_item(item_id: String) -> int:
	return inventory.count(item_id)


## Eat/drink/use one of item_id from inventory: applies need effects, logs
## calories for the daily body tick, removes one instance. False if absent
## or not consumable.
func consume_item(item_id: String) -> bool:
	if item_id not in inventory:
		return false
	var item := ContentDB.get_item(item_id)
	if item == null or "consumable" not in item.tags:
		return false
	for need_id in item.need_effects:
		needs.change(need_id, float(item.need_effects[need_id]))
	var hunger_restored := float(item.need_effects.get("hunger", 0.0))
	if hunger_restored > 0.0:
		flags["calories_today"] = int(flags.get("calories_today", 0)) + int(hunger_restored * 25)
	if "booze" in item.tags:
		# Drunk = confident. Confident = the perceived odds lie harder.
		flags["drunk_minutes"] = mini(int(flags.get("drunk_minutes", 0)) + 90, 240)
	inventory.erase(item_id)
	return true


## Per-game-minute upkeep beyond needs decay (the Player node drives this).
func tick_minute() -> void:
	needs.apply_minute()
	var drunk := int(flags.get("drunk_minutes", 0))
	if drunk > 0:
		flags["drunk_minutes"] = drunk - 1


func add_skill_xp(skill: String, xp: float) -> void:
	var fast := 1.3 if has_tag("fast_learner") else 1.0
	var hard := 1.1 if has_tag("hardworking") else 1.0
	skills[skill] = float(skills.get(skill, 0.0)) + xp * fast * hard


func skill_level(skill: String) -> int:
	# Levels at 10, 30, 60, 100, 150... xp (triangular-ish curve).
	var xp := float(skills.get(skill, 0.0))
	var level := 0
	var threshold := 10.0
	while xp >= threshold and level < 10:
		xp -= threshold
		level += 1
		threshold += 10.0
	return level


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
		"dirty_cents": dirty_cents,
		"bank_cents": bank_cents,
		"mickey_debt_cents": mickey_debt_cents,
		"inventory": inventory.duplicate(),
		"job_id": job_id,
		"shifts_worked": shifts_worked,
		"housing_id": housing_id,
		"rent_strikes": rent_strikes,
		"weight_kg": weight_kg,
		"lives_lived": lives_lived,
		"alive": alive,
		"flags": flags.duplicate(true),
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
	sheet.dirty_cents = int(d.get("dirty_cents", 0))
	sheet.bank_cents = int(d.get("bank_cents", 0))
	sheet.mickey_debt_cents = int(d.get("mickey_debt_cents", 0))
	sheet.inventory = d.get("inventory", []).duplicate()
	sheet.job_id = d.get("job_id", "")
	sheet.shifts_worked = int(d.get("shifts_worked", 0))
	sheet.housing_id = d.get("housing_id", "")
	sheet.rent_strikes = int(d.get("rent_strikes", 0))
	sheet.weight_kg = float(d.get("weight_kg", 75.0))
	sheet.lives_lived = int(d.get("lives_lived", 1))
	sheet.alive = d.get("alive", true)
	sheet.flags = d.get("flags", {}).duplicate(true)
	sheet.needs = Needs.from_dict(d.get("needs", {}))
	return sheet
