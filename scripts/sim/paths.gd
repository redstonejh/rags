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
	return paths


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
