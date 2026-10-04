extends Control
## Entry screen for starting the game, configuring options, or exiting.

@onready var play_button: TextureButton = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/PlayButton
@onready var continue_button: TextureButton = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ContinueButton
@onready var options_button: TextureButton = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_button: TextureButton = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/QuitButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var music_director: MusicDirector = $MusicDirector

func _ready() -> void:
	music_director.play_main_menu()
	settings_panel.hide()
	play_button.pressed.connect(_start_game)
	continue_button.pressed.connect(_continue_game)
	continue_button.disabled = not RunState.has_saved_run()
	continue_button.modulate = Color(1.0, 1.0, 1.0, 1.0 if not continue_button.disabled else 0.42)
	options_button.pressed.connect(settings_panel.show)
	quit_button.pressed.connect(get_tree().quit)
	_connect_ui_sounds(self)


func _start_game() -> void:
	RunState.clear_saved_run()
	SceneRouter.show_ship_select()


func _continue_game() -> void:
	if not RunState.load_saved_run():
		continue_button.disabled = true
		continue_button.modulate = Color(1.0, 1.0, 1.0, 0.42)
		return
	SceneRouter.show_game()


func _connect_ui_sounds(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is BaseButton and not child.button_down.is_connected(_play_ui_select):
			child.button_down.connect(_play_ui_select)
		_connect_ui_sounds(child)


func _play_ui_select() -> void:
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("ui_select", null, "Menu")
