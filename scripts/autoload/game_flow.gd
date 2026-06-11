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


func start_new_game(sheet: CharacterSheet) -> void:
	WorldState.new_game(sheet)
	_enter_world()


func continue_game() -> void:
	if SaveManager.load_game():
		_enter_world()
	else:
		push_error("GameFlow: no loadable save")


func _enter_world() -> void:
	SaveManager.set_in_game(true)
	get_tree().change_scene_to_file(GAME)
