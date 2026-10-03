extends Area2D
## Applies a temporary sensor-range/signature multiplier to ships inside the field.
# NebulaField applies sensor interference to ships inside its collision shape.
class_name NebulaField

## Sensor-range and signature multiplier applied to ships while inside the Area2D.
@export_range(0.1, 1.0, 0.05) var sensor_multiplier: float = 0.35
@onready var nebula_visual: Sprite2D = $NebulaVisual


func _ready() -> void:
	add_to_group("sensor_contact")
	set_meta("contact_type", "nebula")
	set_meta("sensor_signature", 0.7)
	# Area membership is gameplay; the visual child never determines field coverage.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Mirror only the cloud sprite across sector seams, not its collision field.
	SectorSpace.register_wrap_visual(self, nebula_visual)


func _exit_tree() -> void:
	SectorSpace.unregister_wrap_visual(self)


func _on_body_entered(body: Node2D) -> void:
	_set_ship_sensor_effect(body, sensor_multiplier)


func _on_body_exited(body: Node2D) -> void:
	_set_ship_sensor_effect(body, 1.0)


func _set_ship_sensor_effect(body: Node2D, multiplier: float) -> void:
	# Non-ship bodies such as asteroids do not have sensor systems.
	if not body is BaseShip:
		return

	var sensors := body.get_node_or_null("SensorComponent") as SensorComponent
	if sensors == null:
		return

	sensors.nebula_sensor_multiplier = multiplier
	sensors.nebula_signature_multiplier = multiplier
	Log.debug("Nebula sensor effect changed", body.name, multiplier)
