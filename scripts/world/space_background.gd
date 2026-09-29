extends CanvasLayer
## Screen-space star layers that respond to continuous player motion across sector wraps.
class_name SpaceBackground

@onready var far_stars: ColorRect = $FarStars
@onready var near_stars: ColorRect = $NearStars


var previous_camera_position: Vector2 = Vector2.ZERO
var has_previous_camera_position: bool = false


func _process(delta: float) -> void:
	
	# The canonical position jumps at a seam; feed shaders the accumulated continuous one.
	var player := get_tree().get_first_node_in_group("player_ship") as BaseShip
	if not is_instance_valid(player):
		return

	var current_camera_position: Vector2 = player.unwrapped_world_position
	var normalized_camera_velocity: Vector2 = Vector2.ZERO
	if has_previous_camera_position and delta > 0.0:
		var reference_speed: float = maxf(player.max_speed, 1.0)
		normalized_camera_velocity = (current_camera_position - previous_camera_position) / (delta * reference_speed)
		normalized_camera_velocity = normalized_camera_velocity.limit_length(1.5)

	previous_camera_position = current_camera_position
	has_previous_camera_position = true
	_set_material_vector(far_stars, "camera_world_position", current_camera_position)
	_set_material_vector(near_stars, "camera_world_position", current_camera_position)
	_set_material_vector(far_stars, "camera_velocity", normalized_camera_velocity)
	_set_material_vector(near_stars, "camera_velocity", normalized_camera_velocity)
	

func _set_material_vector(item: CanvasItem, parameter: StringName, value: Vector2) -> void:
	var shader_material := item.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(parameter, value)
