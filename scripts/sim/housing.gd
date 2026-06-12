class_name Housing
extends RefCounted
## Housing gates and home comfort. Static helpers over the sheet + defs —
## the phone's Home app and EconomySystem both call through here.

## "" if the sheet can sign the lease; otherwise the blocker, in plain words.
static func rent_blocker(sheet: CharacterSheet, def: HousingDef) -> String:
	if sheet.housing_id == def.id:
		return "you live here"
	if def.requires_id and not sheet.flags.get("has_id", false):
		return "needs ID"
	if sheet.outfit_tier() < def.min_outfit_tier:
		return "dress the part (tier %d)" % def.min_outfit_tier
	var employed_ok := def.min_weeks_employed > 0 \
			and int(sheet.flags.get("weeks_employed", 0)) >= def.min_weeks_employed
	var rent_ok := def.min_clean_rent_weeks > 0 \
			and int(sheet.flags.get("clean_rent_weeks", 0)) >= def.min_clean_rent_weeks
	if (def.min_weeks_employed > 0 or def.min_clean_rent_weeks > 0) \
			and not (employed_ok or rent_ok):
		return "needs %d wks employed or %d wks clean rent" % [
			def.min_weeks_employed, def.min_clean_rent_weeks]
	if sheet.cash_cents < def.deposit_cents:
		return "deposit $%d" % (def.deposit_cents / 100)
	return ""


static func move_in(sheet: CharacterSheet, def: HousingDef) -> bool:
	if rent_blocker(sheet, def) != "":
		return false
	if def.deposit_cents > 0:
		sheet.add_cash(-def.deposit_cents)
	sheet.housing_id = def.id
	sheet.rent_strikes = 0
	sheet.flags.erase("home_owned")
	EventBus.path_updated.emit()
	EventBus.toast.emit("Moved in: %s. %s" % [def.display_name,
			"Rent is $%d, Mondays." % (def.weekly_rent_cents / 100) if def.weekly_rent_cents > 0 else "No rent. Just rules."])
	return true


static func buy_blocker(sheet: CharacterSheet, def: HousingDef) -> String:
	if def.buy_price_cents <= 0:
		return "not for sale"
	if sheet.flags.get("home_owned", false) and sheet.housing_id == def.id:
		return "you own it"
	if def.requires_id and not sheet.flags.get("has_id", false):
		return "needs ID"
	if sheet.credit_score < def.min_credit_to_buy:
		return "credit %d needed (yours: %d)" % [def.min_credit_to_buy, sheet.credit_score]
	if sheet.cash_cents < def.down_payment_cents:
		return "down payment $%d" % (def.down_payment_cents / 100)
	return ""


## Pay the down payment; the weekly number becomes a mortgage. The bank is
## just a landlord with better stationery.
static func buy(sheet: CharacterSheet, def: HousingDef) -> bool:
	if buy_blocker(sheet, def) != "":
		return false
	sheet.add_cash(-def.down_payment_cents)
	sheet.housing_id = def.id
	sheet.rent_strikes = 0
	sheet.flags["home_owned"] = true
	EventBus.path_updated.emit()
	EventBus.toast.emit("SOLD: %s. The mailbox has your name on it. The bank has everything else." % def.display_name)
	return true


static func furniture_blocker(sheet: CharacterSheet, def: FurnitureDef) -> String:
	if def == null:
		return "unknown item"
	if def.id in sheet.furniture:
		return "owned"
	if sheet.housing_id == "":
		return "no home"
	if sheet.cash_cents < def.cost_cents:
		return "can't afford"
	return ""


static func buy_furniture(sheet: CharacterSheet, def: FurnitureDef) -> bool:
	if furniture_blocker(sheet, def) != "":
		return false
	sheet.add_cash(-def.cost_cents)
	sheet.furniture.append(def.id)
	EventBus.path_updated.emit()
	EventBus.toast.emit("Delivered: %s. Home gains a personality." % def.display_name)
	return true


## Best owned furniture quality of a kind ("bed"/"tv"), floor 1.0.
static func furniture_quality(sheet: CharacterSheet, kind: String) -> float:
	var best := 1.0
	for fid in sheet.furniture:
		var f := ContentDB.get_furniture(fid)
		if f and f.kind == kind:
			best = maxf(best, f.quality)
	return best


## Tier comfort + everything you own, capped — home quality feeds Mood.
static func comfort_total(sheet: CharacterSheet) -> float:
	var def := ContentDB.get_housing(sheet.housing_id)
	if def == null:
		return 0.0
	var total := def.comfort
	var seen := {}
	for fid in sheet.furniture:
		if seen.has(fid):
			continue
		seen[fid] = true
		var f := ContentDB.get_furniture(fid)
		if f:
			total += f.comfort
	return minf(total, 30.0)
