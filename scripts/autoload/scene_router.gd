extends Node
## Performs scene transitions using PackedScenes assigned in the saved autoload scene.

@export var main_menu_scene: PackedScene
@export var ship_select_scene: PackedScene
@export var game_scene: PackedScene


func show_main_menu() -> void:
	_change_to(main_menu_scene, "main menu")


func show_ship_select() -> void:
	_change_to(ship_select_scene, "ship selection")


func show_game() -> void:
	_change_to(game_scene, "game")


func _change_to(scene: PackedScene, label: String) -> void:
	if scene == null:
		Log.error("SceneRouter has no saved scene assigned", label)
		return
	get_tree().change_scene_to_packed(scene)
