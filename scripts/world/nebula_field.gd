extends Area2D
# NebulaField applies sensor interference to ships inside its collision shape.
class_name NebulaField

@export_range(0.1, 1.0, 0.05) var sensor_multiplier: float = 0.35


func _ready() -> void:
	# Area membership is gameplay; the visual child never determines field coverage.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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
