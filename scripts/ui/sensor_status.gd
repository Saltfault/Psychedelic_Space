extends Label
# NEW CODE STARTS HERE
# Show the player when its own sensors are attenuated by a nebula.
var player_sensor: SensorComponent = null

func _ready() -> void:
	visible = false

func _process(_delta: float) -> void:
	if not is_instance_valid(player_sensor):
		var player_node: Node = get_tree().get_first_node_in_group("player_ship")
		if player_node != null:
			player_sensor = player_node.get_node_or_null("SensorComponent") as SensorComponent

	if not is_instance_valid(player_sensor):
		visible = false
		return

	var range_multiplier: float = player_sensor.nebula_sensor_multiplier
	visible = range_multiplier < 0.999
	if visible:
		text = "SENSOR INTERFERENCE - RANGE %d%%" % roundi(range_multiplier * 100.0)
# NEW CODE ENDS HERE