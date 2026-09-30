extends Control
## Entry screen for starting the game, configuring options, or exiting.

@onready var play_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/QuitButton
@onready var settings_panel: PanelContainer = $SettingsPanel


func _ready() -> void:
	settings_panel.hide()
	play_button.pressed.connect(_start_game)
	settings_button.pressed.connect(settings_panel.show)
	quit_button.pressed.connect(get_tree().quit)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
