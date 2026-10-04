extends CanvasLayer
## Applies the saved dither shader to gameplay before the HUD is drawn.

@onready var overlay: ColorRect = $Overlay
@onready var shader_material: ShaderMaterial = overlay.material as ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.settings_changed.connect(_sync_settings)
	get_tree().node_added.connect(_on_scene_node_added)
	_sync_settings()


func _process(_delta: float) -> void:
	# Keep the screen-wide pass on gameplay; scene-authored UI art gets its own text-safe material.
	_sync_visibility()


func _sync_settings() -> void:
	_apply_dither_settings(shader_material)
	for visual in get_tree().get_nodes_in_group("dither_ui_visual"):
		if visual is CanvasItem:
			_apply_dither_settings((visual as CanvasItem).material as ShaderMaterial)
	_sync_visibility()


func _on_scene_node_added(node: Node) -> void:
	# Scene-authored icon and meter materials join the effect as their UI scenes enter the tree.
	if node.is_in_group("dither_ui_visual") and node is CanvasItem:
		_apply_dither_settings((node as CanvasItem).material as ShaderMaterial)


func _apply_dither_settings(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("effect_enabled", GameSettings.dither_enabled)
	material.set_shader_parameter("pixel_size", GameSettings.dither_pixel_size)
	material.set_shader_parameter("palette_mode", GameSettings.dither_palette_mode)
	material.set_shader_parameter("levels", GameSettings.dither_levels)
	material.set_shader_parameter("dither_mode", GameSettings.dither_mode)
	material.set_shader_parameter("dither_strength", GameSettings.dither_strength)
	material.set_shader_parameter("brightness", GameSettings.dither_brightness)
	material.set_shader_parameter("contrast", GameSettings.dither_contrast)


func _sync_visibility() -> void:
	var scene: Node = get_tree().current_scene
	var gameplay_active: bool = is_instance_valid(scene) and scene.is_in_group("dithered_world_scene")
	overlay.visible = GameSettings.dither_enabled and gameplay_active
