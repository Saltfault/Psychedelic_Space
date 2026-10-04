extends Control
## Shows edge-of-screen direction markers for off-screen stations and outposts in sensor range.
class_name LongRangeSensor

@export var marker_scene: PackedScene

@onready var marker_container: Node2D = $MarkerContainer

var player: PlayerShip
var sensor: SensorComponent
var markers_by_id: Dictionary = {}


## Bind the player's live sensor statistic; modules then automatically extend radar reach.
func configure(target_player: PlayerShip) -> void:
	player = target_player
	sensor = player.get_node_or_null("SensorComponent") as SensorComponent


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_clear_markers()
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = viewport_size * 0.5
	marker_container.position = center
	var edge_radius: float = minf(viewport_size.x, viewport_size.y) * 0.465
	var visible_screen: Rect2 = Rect2(Vector2.ZERO, viewport_size).grow(-48.0)
	var seen: Dictionary = {}
	var targets: Array[Node] = get_tree().get_nodes_in_group("station")
	targets.append_array(get_tree().get_nodes_in_group("main_objective"))
	targets.append_array(get_tree().get_nodes_in_group("warp_gate"))
	for target_node: Node in targets:
		var target: Node2D = target_node as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var delta: Vector2 = SectorSpace.shortest_delta(player.global_position, target.global_position)
		var distance: float = delta.length()
		var sensor_multiplier: float = sensor.nebula_sensor_multiplier if sensor != null else 1.0
		var effective_range: float = player.sensor_range * sensor_multiplier
		if distance > effective_range or distance <= 0.001:
			continue
		var target_screen_position: Vector2 = target.get_global_transform_with_canvas().origin
		if visible_screen.has_point(target_screen_position):
			continue
		var marker_id: int = target.get_instance_id()
		seen[marker_id] = true
		var marker: LongRangeSensorMarker = markers_by_id.get(marker_id) as LongRangeSensorMarker
		if marker == null:
			if marker_scene == null:
				Log.error("LongRangeSensor scene is missing its saved marker scene", get_path())
				return
			marker = marker_scene.instantiate() as LongRangeSensorMarker
			marker_container.add_child(marker)
			markers_by_id[marker_id] = marker
		var marker_type: StringName = &"station"
		if target.is_in_group("main_objective"):
			marker_type = &"outpost"
		elif target.is_in_group("warp_gate"):
			marker_type = &"warp_gate"
		marker.configure(marker_type)
		marker.position = delta.normalized() * edge_radius
		marker.rotation = delta.angle() + PI * 0.5

	for marker_id: Variant in markers_by_id.keys():
		if seen.has(marker_id):
			continue
		var stale_marker: LongRangeSensorMarker = markers_by_id[marker_id] as LongRangeSensorMarker
		stale_marker.queue_free()
		markers_by_id.erase(marker_id)


func _clear_markers() -> void:
	for marker_value: Variant in markers_by_id.values():
		var marker: LongRangeSensorMarker = marker_value as LongRangeSensorMarker
		marker.queue_free()
	markers_by_id.clear()
