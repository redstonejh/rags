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


func _enter_world() -> void:
	SaveManager.set_in_game(true)
	get_tree().change_scene_to_file(GAME)
