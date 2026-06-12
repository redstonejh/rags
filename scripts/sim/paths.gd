class_name LifePaths
extends RefCounted
## Life Paths: legible UI over systemic requirements. A path never railroads —
## it just shows the current blocker. M3 ships the first one: "Getting Off the
## Street" (the ID quest) for no_papers origins. More paths land in M7.

const ID_FEE_CENTS := RecordsDesk.ID_FEE_CENTS


## -> [{name: String, steps: [{label: String, done: bool, current: bool}]}]
static func evaluate(sheet: CharacterSheet) -> Array:
	var paths: Array = []
	if sheet.has_tag("no_papers"):
		paths.append(_getting_off_the_street(sheet))
	var worst := Body.worst_addiction(sheet)
	if float(worst.addiction) > 0.05 or int(worst.clean_days) > 0:
		paths.append(_recovery(worst))
	paths.append(_education(sheet))
	return paths


## Generalizes the Tweaker's arc to every substance: clean days are the
## only currency, and the counter resets the moment you don't mean it.
static func _recovery(worst: Dictionary) -> Dictionary:
	var clean := int(worst.clean_days)
	var steps: Array = [
		{"label": "Admit the %s has the wheel" % str(worst.id), "done": true},
		{"label": "Detox: 3 days clean (the gauntlet)", "done": clean >= 3},
		{"label": "The hard week: 7 days clean", "done": clean >= 7},
		{"label": "30 days clean — the chip, and the willpower that comes with it",
			"done": clean >= 30},
	]
	return _mark_current({"name": "Recovery (%d days clean)" % clean, "steps": steps})


static func _education(sheet: CharacterSheet) -> Dictionary:
	var enrolled: bool = sheet.flags.has("ged_done_day")
	var done: bool = sheet.flags.get("ged", false) or sheet.skill_level("education") >= 1
	var steps: Array = [
		{"label": "Scrape together the $200 GED course fee",
			"done": done or enrolled or sheet.cash_cents >= 20000},
		{"label": "Enroll in night classes (phone)", "done": done or enrolled},
		{"label": "Two weeks of Tuesdays that taste like burnt coffee", "done": done},
		{"label": "GED in hand — office doors open", "done": done},
	]
	return _mark_current({"name": "Education", "steps": steps})


static func _mark_current(path: Dictionary) -> Dictionary:
	var found := false
	for step in path.steps:
		step["current"] = not step.done and not found
		if step.current:
			found = true
	return path


static func _getting_off_the_street(sheet: CharacterSheet) -> Dictionary:
	var has_id: bool = sheet.flags.get("has_id", false)
	var filed: bool = sheet.flags.has("id_ready_day")
	var ready_day := int(sheet.flags.get("id_ready_day", -1))
	var waited: bool = has_id or (filed and GameClock.day >= ready_day)

	var steps: Array = [
		{"label": "Scrape together the $%d ID fee" % (ID_FEE_CENTS / 100),
			"done": has_id or filed or sheet.cash_cents >= ID_FEE_CENTS},
		{"label": "File at the records desk, Vantage Plaza (Window 3 is closed)",
			"done": has_id or filed},
		{"label": "Survive the processing wait" + (" (ready day %d)" % ready_day if filed and not has_id else ""),
			"done": waited},
		{"label": "Pick up your ID. Exist, officially.",
			"done": has_id},
	]
	var current_found := false
	for step in steps:
		step["current"] = not step.done and not current_found
		if step.current:
			current_found = true
	return {"name": "Getting Off the Street", "steps": steps}
