class_name EconomySystem
extends Node
## The weekly and daily money/body grind. Plain Node in Main.tscn.
##
## Monday (day % 7 == 0): rent comes due, and Big Mickey's ledger compounds.
## Every day: the body tick — weight follows calories, and starvation is a
## telegraphed, multi-day death (fat is a buffer; then it isn't).

const RENTS := {
	"bricks_unit": 9000,        # $90/wk — the Bricks
	"decent_apartment": 20000,  # $200/wk — the exec's old life, prorated
}
const HOUSING_NAMES := {
	"bricks_unit": "your unit at the Bricks",
	"decent_apartment": "the decent apartment",
}
const EVICTION_STRIKES := 3

const MICKEY_WEEKLY_INTEREST := 0.20
const MICKEY_BEATING_THRESHOLD_CENTS := 150000  # $1,500: Mickey sends the boys

const KCAL_MAINTENANCE := 2000.0
const KCAL_PER_KG := 7700.0
const STARVING_BURN_KG_PER_DAY := 0.4
const DEATH_WEIGHT_KG := 45.0


func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)


func _on_day_passed(day: int) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null or not sheet.alive:
		return
	_body_tick(sheet)
	if not sheet.alive:
		return
	if day % 7 == 0: # Monday. Of course it's Monday.
		_collect_rent(sheet)
		_mickey_tick(sheet)


# ---------------------------------------------------------------- housing

func _collect_rent(sheet: CharacterSheet) -> void:
	if not RENTS.has(sheet.housing_id):
		return
	var rent: int = RENTS[sheet.housing_id]
	var home: String = HOUSING_NAMES.get(sheet.housing_id, "home")
	var prepaid := int(sheet.flags.get("rent_prepaid_weeks", 0))
	if prepaid > 0:
		sheet.flags["rent_prepaid_weeks"] = prepaid - 1
		EventBus.toast.emit("Rent on %s: covered. %d prepaid week%s left." % [
			home, prepaid - 1, "" if prepaid - 1 == 1 else "s"])
		return
	if sheet.cash_cents >= rent:
		sheet.add_cash(-rent)
		if sheet.rent_strikes > 0:
			sheet.rent_strikes = 0
		EventBus.toast.emit("Rent paid: $%.2f. The roof remains, technically, yours." % (rent / 100.0))
		return
	sheet.rent_strikes += 1
	if sheet.rent_strikes >= EVICTION_STRIKES:
		sheet.housing_id = ""
		sheet.rent_strikes = 0
		EventBus.toast.emit("The locks have been changed. The landlord kept the deposit, and the high ground.")
	else:
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
