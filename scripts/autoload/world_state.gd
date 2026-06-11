extends Node
## ALL mutable simulation state lives here (and only here). This is what
## gets saved. M1: the player sheet. M2 adds the NPC records, economy, etc.

var player_sheet: CharacterSheet = null


func new_game(sheet: CharacterSheet) -> void:
	player_sheet = sheet
	sheet.rebuild_needs_multipliers()


## Lets Main.tscn run standalone from the editor (F5 on the scene) without
## going through the menu — creates a debug drifter.
func ensure_player_sheet() -> void:
	if player_sheet != null:
		return
	var sheet := CharacterSheet.new()
	sheet.char_name = "Debug Drifter"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 40000
	new_game(sheet)


func to_dict() -> Dictionary:
	return {
		"player": player_sheet.to_dict() if player_sheet else {},
	}


func load_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("player", {})
	player_sheet = CharacterSheet.from_dict(p) if not p.is_empty() else null
	if player_sheet:
		player_sheet.rebuild_needs_multipliers()
