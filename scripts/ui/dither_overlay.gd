extends CanvasLayer
## Applies the saved dither shader to gameplay before the HUD is drawn.

@onready var overlay: ColorRect = $Overlay
@onready var shader_material: ShaderMaterial = overlay.material as ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.settings_changed.connect(_sync_settings)
	_sync_settings()


func _process(_delta: float) -> void:
	# Only gameplay opts in; title, ship-select, and other menus stay crisp.
	_sync_visibility()


func _sync_settings() -> void:
	shader_material.set_shader_parameter("pixel_size", GameSettings.dither_pixel_size)
	shader_material.set_shader_parameter("palette_mode", GameSettings.dither_palette_mode)
	shader_material.set_shader_parameter("levels", GameSettings.dither_levels)
	shader_material.set_shader_parameter("dither_mode", GameSettings.dither_mode)
	shader_material.set_shader_parameter("dither_strength", GameSettings.dither_strength)
	shader_material.set_shader_parameter("brightness", GameSettings.dither_brightness)
	shader_material.set_shader_parameter("contrast", GameSettings.dither_contrast)
	_sync_visibility()


func _sync_visibility() -> void:
	var scene: Node = get_tree().current_scene
	var gameplay_active: bool = is_instance_valid(scene) and scene.is_in_group("dithered_world_scene")
	overlay.visible = GameSettings.dither_enabled and gameplay_active
