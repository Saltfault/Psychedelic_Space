extends Control
## Draws nearby sensor contacts using wrapped positions and contact metadata.
class_name Minimap

@export_range(1.0, 10000.0, 100.0) var map_range: float = 3200.0

var player: PlayerShip
var sensor: SensorComponent


## Bind the player whose sensor contacts and position this minimap should display.
func configure(target_player: PlayerShip) -> void:
	player = target_player
	sensor = player.get_node_or_null("SensorComponent") as SensorComponent
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46

	draw_circle(center, radius, Color(0.03, 0.05, 0.09, 0.85))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.35, 0.8, 1.0, 0.8), 2.0)

	if not is_instance_valid(player):
		return

	draw_circle(center, 4.0, Color.WHITE)

	if sensor != null:
		for contact: Node2D in sensor.contacts:
			if not is_instance_valid(contact) or contact.is_in_group("main_objective"):
				continue
			_draw_contact(contact, center, radius)

	# The mission objective is mission knowledge, not a sensor contact; always show its real position.
	var objective: Node2D = get_tree().get_first_node_in_group("main_objective") as Node2D
	if is_instance_valid(objective):
		_draw_marker(objective, center, radius, Color(1.0, 0.2, 0.8), 6.0)


func _draw_contact(contact: Node2D, center: Vector2, radius: float) -> void:
	var contact_type: String = str(contact.get_meta("contact_type", "unknown"))
	var color: Color = Color(1.0, 0.75, 0.25)

	match contact_type:
		"station":
			color = Color(0.3, 1.0, 0.55)
		"outpost":
			color = Color(1.0, 0.25, 0.35)
		"caravan":
			color = Color(1.0, 0.8, 0.2)
		"intel":
			color = Color(0.2, 0.9, 1.0)
		"warp":
			color = Color(1.0, 0.25, 0.95)

	_draw_marker(contact, center, radius, color, 4.0)


func _draw_marker(
	target: Node2D,
	center: Vector2,
	radius: float,
	color: Color,
	marker_radius: float,
) -> void:
	var delta: Vector2 = SectorSpace.shortest_delta(player.global_position, target.global_position)
	var range_for_display: float = maxf(map_range, 1.0)
	var normalized_distance: float = minf(delta.length() / range_for_display, 1.0)
	var direction: Vector2 = Vector2.RIGHT
	if delta.length_squared() > 0.001:
		direction = delta.normalized()

	var point: Vector2 = center + direction * radius * normalized_distance
	draw_circle(point, marker_radius, color)
