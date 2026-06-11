extends Control
## Title screen: New Life / Continue / Quit.

@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save()
	%NewLifeButton.pressed.connect(func() -> void: GameFlow.to_character_creation())
	continue_button.pressed.connect(func() -> void: GameFlow.continue_game())
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
