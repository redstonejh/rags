extends Node
## Scene transitions and game lifecycle: menu -> character creation -> world.

const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const CHARACTER_CREATION := "res://scenes/ui/CharacterCreation.tscn"
const GAME := "res://scenes/main/Main.tscn"


func to_main_menu() -> void:
	SaveManager.save_game() # no-op unless in game
	SaveManager.set_in_game(false)
	get_tree().change_scene_to_file(MAIN_MENU)


func to_character_creation() -> void:
	get_tree().change_scene_to_file(CHARACTER_CREATION)


## First life builds a town; later lives (after a death or walk-away) join
## the town that's already there — NPCs, graves, grudges and all.
func start_new_game(sheet: CharacterSheet) -> void:
	var previous_life_over: bool = WorldState.player_sheet == null \
			or not WorldState.player_sheet.alive
	if WorldState.world_exists and not WorldState.npcs.is_empty() and previous_life_over:
		WorldState.start_life(sheet)
	else:
		WorldState.new_world(sheet)
	_enter_world()


func continue_game() -> void:
	if SaveManager.load_game():
		# A dead save isn't a corpse to pilot — the town survived you.
		# Roll the next life into the same world.
		if WorldState.player_sheet == null or not WorldState.player_sheet.alive:
			to_character_creation()
		else:
			_enter_world()
	else:
		push_error("GameFlow: no loadable save")


## The signature inheritance: continue as your grown child. The house, the
## money, and the family reputation come with the name.
func continue_as_heir(kid: Dictionary) -> void:
	var parent := WorldState.player_sheet
	var sheet := CharacterSheet.new()
	sheet.char_name = "%s %s" % [str(kid.get("name", "Kid")),
			parent.char_name.get_slice(" ", 1) if " " in parent.char_name else "Jr."]
	sheet.origin_id = "off_the_bus" # heirs start fresh on paper
	sheet.age_years = (GameClock.day - int(kid.get("born_day", 0))) / Body.DAYS_PER_YEAR
	sheet.cash_cents = parent.cash_cents + parent.bank_cents # the estate, settled fast
	sheet.housing_id = parent.housing_id
	sheet.furniture = parent.furniture.duplicate()
	if parent.flags.get("home_owned", false):
		sheet.flags["home_owned"] = true
	sheet.flags["has_id"] = true
	sheet.flags["heir_of"] = parent.char_name
	for t in kid.get("traits", []):
		sheet.flags["childhood_" + str(t)] = true
	WorldState.start_life(sheet)
	_enter_world()


func _enter_world() -> void:
	SaveManager.set_in_game(true)
	get_tree().change_scene_to_file(GAME)
