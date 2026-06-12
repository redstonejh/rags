class_name EconomySystem
extends Node
## The weekly and daily money/body grind. Plain Node in Main.tscn.
##
## Monday (day % 7 == 0): rent comes due, and Big Mickey's ledger compounds.
## Every day: the body tick — weight follows calories, and starvation is a
## telegraphed, multi-day death (fat is a buffer; then it isn't).

const EVICTION_STRIKES := 3
const CREDIT_ON_TIME := 1
const CREDIT_MISSED := -5
const CREDIT_EVICTED := -15

const MICKEY_WEEKLY_INTEREST := 0.20
const MICKEY_BEATING_THRESHOLD_CENTS := 150000  # $1,500: Mickey sends the boys

const KCAL_MAINTENANCE := 2000.0
const KCAL_PER_KG := 7700.0
const STARVING_BURN_KG_PER_DAY := 0.4
const DEATH_WEIGHT_KG := 45.0


func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)


func _on_day_passed(day: int) -> void:
	Body.age_npcs() # the town's population turns over across a long game
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null or not sheet.alive:
		return
	Body.daily_tick(sheet) # substances, wounds, aging, kids
	if not sheet.alive:
		return
	_body_tick(sheet)
	if not sheet.alive:
		return
	if day % 7 == 0: # Monday. Of course it's Monday.
		if sheet.job_id != "":
			sheet.flags["weeks_employed"] = int(sheet.flags.get("weeks_employed", 0)) + 1
		_collect_rent(sheet)
		_mickey_tick(sheet)
		_stat_drift(sheet)


## Lifestyle drift: tunnel on one thing and it pulls the other down. Slow,
## weekly, and always announced — "your jeans fit differently."
func _stat_drift(sheet: CharacterSheet) -> void:
	var phys := float(sheet.flags.get("drift_phys", 0.0))
	var mind := float(sheet.flags.get("drift_mind", 0.0))
	sheet.flags["drift_phys"] = 0.0
	sheet.flags["drift_mind"] = 0.0
	if phys >= 10.0 and phys >= mind * 2.0:
		if int(sheet.base_stats["STR"]) < 16:
			sheet.base_stats["STR"] = int(sheet.base_stats["STR"]) + 1
			sheet.base_stats["INT"] = maxi(int(sheet.base_stats["INT"]) - 1, 4)
			EventBus.toast.emit("Your jeans fit differently. STR +1, INT -1. You stopped reading.")
	elif mind >= 10.0 and mind >= phys * 2.0:
		if int(sheet.base_stats["INT"]) < 16:
			sheet.base_stats["INT"] = int(sheet.base_stats["INT"]) + 1
			sheet.base_stats["STR"] = maxi(int(sheet.base_stats["STR"]) - 1, 4)
			EventBus.toast.emit("All those evenings studying. INT +1, STR -1. The jar lids win now.")


# ---------------------------------------------------------------- housing

func _collect_rent(sheet: CharacterSheet) -> void:
	var def := ContentDB.get_housing(sheet.housing_id)
	if def == null or def.weekly_rent_cents <= 0:
		return
	var rent := def.weekly_rent_cents
	var prepaid := int(sheet.flags.get("rent_prepaid_weeks", 0))
	if prepaid > 0:
		sheet.flags["rent_prepaid_weeks"] = prepaid - 1
		EventBus.path_updated.emit()
		EventBus.toast.emit("Rent on %s: covered. %d prepaid week%s left." % [
			def.display_name, prepaid - 1, "" if prepaid - 1 == 1 else "s"])
		return
	if sheet.cash_cents >= rent:
		sheet.add_cash(-rent)
		sheet.rent_strikes = 0
		sheet.credit_score = clampi(sheet.credit_score + CREDIT_ON_TIME, 0, 100)
		sheet.flags["clean_rent_weeks"] = int(sheet.flags.get("clean_rent_weeks", 0)) + 1
		EventBus.path_updated.emit()
		EventBus.toast.emit("%s: $%.2f. The roof remains, technically, yours." % [
			"Mortgage paid" if sheet.flags.get("home_owned", false) else "Rent paid", rent / 100.0])
		return
	sheet.rent_strikes += 1
	sheet.credit_score = clampi(sheet.credit_score + CREDIT_MISSED, 0, 100)
	sheet.flags["clean_rent_weeks"] = 0
	if sheet.rent_strikes >= EVICTION_STRIKES:
		sheet.housing_id = ""
		sheet.rent_strikes = 0
		sheet.flags.erase("home_owned")
		sheet.credit_score = clampi(sheet.credit_score + CREDIT_EVICTED, 0, 100)
		EventBus.path_updated.emit()
		EventBus.toast.emit("The locks have been changed. The landlord kept the deposit, and the high ground.")
	else:
		EventBus.path_updated.emit()
		EventBus.toast.emit("Rent missed (%d/%d). The landlord's patience is not a renewable resource." % [
			sheet.rent_strikes, EVICTION_STRIKES])


# ---------------------------------------------------------------- the shark

func _mickey_tick(sheet: CharacterSheet) -> void:
	if sheet.mickey_debt_cents <= 0:
		return
	sheet.mickey_debt_cents = int(sheet.mickey_debt_cents * (1.0 + MICKEY_WEEKLY_INTEREST))
	EventBus.toast.emit("Mickey's ledger grew: you owe $%.2f. Interest never sleeps." % (sheet.mickey_debt_cents / 100.0))
	if sheet.mickey_debt_cents > MICKEY_BEATING_THRESHOLD_CENTS:
		sheet.needs.change("energy", -40.0)
		EventBus.toast.emit("Two large men explain compound interest with their hands. Next time it's the kneecaps.")


# ---------------------------------------------------------------- the body

func _body_tick(sheet: CharacterSheet) -> void:
	var kcal := float(sheet.flags.get("calories_today", 0))
	var delta_kg := (kcal - KCAL_MAINTENANCE) / KCAL_PER_KG
	if sheet.needs.get_value("hunger") <= 0.0:
		delta_kg -= STARVING_BURN_KG_PER_DAY
	sheet.weight_kg = clampf(sheet.weight_kg + delta_kg, 30.0, 250.0)
	sheet.flags["calories_today"] = 0
	if sheet.weight_kg < DEATH_WEIGHT_KG:
		EventBus.player_died.emit("starvation")
