extends Control
## Positions saved marker scenes from the player's current sensor contacts.
class_name Minimap

@export_range(1.0, 10000.0, 100.0) var map_range: float = 3200.0
@export var marker_scene: PackedScene
@export var station_icon: Texture2D
@export var outpost_icon: Texture2D
@export var enemy_icon: Texture2D
@export var intel_icon: Texture2D
@export var warp_icon: Texture2D
@export var weapon_icon: Texture2D
@export var module_icon: Texture2D
@export var asteroid_icon: Texture2D
@export var nebula_icon: Texture2D
@export var planet_icon: Texture2D

@onready var marker_layer: Control = $Markers
@onready var player_marker: TextureRect = $PlayerMarker

var player: PlayerShip
var sensor: SensorComponent


func _ready() -> void:
	# Expose the live minimap range to spawners via a single shared group.
	add_to_group("minimap")
var _markers_by_id: Dictionary = {}


## Bind the player whose sensor contacts and position this minimap should display.
func configure(target_player: PlayerShip) -> void:
	player = target_player
	sensor = player.get_node_or_null("SensorComponent") as SensorComponent
	player_marker.visible = is_instance_valid(player)
	_refresh_markers()


func _process(_delta: float) -> void:
	_refresh_markers()


func _refresh_markers() -> void:
	if not is_instance_valid(player):
		_clear_markers()
		player_marker.hide()
		return
	player_marker.show()
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.31
	var seen: Dictionary = {}
	if sensor != null:
		for contact: Node2D in sensor.contacts:
			if not is_instance_valid(contact) or contact.is_in_group("main_objective"):
				continue
			var marker_data: Dictionary = _contact_style(contact)
			if marker_data.is_empty():
				continue
			var marker_id: int = contact.get_instance_id()
			seen[marker_id] = true
			_sync_marker(marker_id, contact, center, radius, marker_data)

	# Mission knowledge is shown independently from sensor contact/range.
	var objective: Node2D = get_tree().get_first_node_in_group("main_objective") as Node2D
	if is_instance_valid(objective):
		var objective_id: int = objective.get_instance_id()
		seen[objective_id] = true
		var objective_marker_data: Dictionary = _contact_style(objective)
		objective_marker_data["icon"] = outpost_icon
		objective_marker_data["color"] = Color(1.0, 0.2, 0.8)
		objective_marker_data["diameter"] = 12.0
		_sync_marker(
			objective_id,
			objective,
			center,
			radius,
			objective_marker_data,
		)
	for old_id: Variant in _markers_by_id.keys():
		if seen.has(old_id):
			continue
		var old_marker: MinimapMarker = _markers_by_id[old_id] as MinimapMarker
		old_marker.queue_free()
		_markers_by_id.erase(old_id)


func _contact_style(contact: Node2D) -> Dictionary:
	var contact_type: String = str(contact.get_meta("contact_type", "unknown"))
	var tint: Color = Color(1.0, 0.75, 0.25)
	var icon: Texture2D = null
	var diameter: float = 8.0
	match contact_type:
		"station":
			tint = Color(0.3, 1.0, 0.55)
			icon = station_icon
		"outpost":
			tint = Color(1.0, 0.25, 0.35)
			icon = outpost_icon
		"caravan":
			tint = Color(1.0, 0.8, 0.2)
			icon = enemy_icon
		"intel":
			tint = Color(0.2, 0.9, 1.0)
			icon = intel_icon
		"warp":
			tint = Color(1.0, 0.25, 0.95)
			icon = warp_icon
		"enemy":
			icon = enemy_icon
		"weapon":
			icon = weapon_icon
		"module":
			icon = module_icon
		"asteroid":
			icon = asteroid_icon
		"nebula":
			icon = nebula_icon
		"planet":
			icon = planet_icon
	if contact.has_meta("planet_id"):
		var planet: PlanetDefinition = RunState.get_planet(
			StringName(str(contact.get_meta("planet_id")))
		)
		if planet != null:
			icon = planet.map_icon
	if contact_type == "unknown":
		return {}
	return {"icon": icon, "color": tint, "diameter": diameter}


func _sync_marker(
	marker_id: int,
	target: Node2D,
	center: Vector2,
	radius: float,
	marker_data: Dictionary,
) -> void:
	var marker: MinimapMarker = _markers_by_id.get(marker_id) as MinimapMarker
	if marker == null:
		if marker_scene == null:
			Log.error("Minimap scene is missing its saved marker scene", get_path())
			return
		marker = marker_scene.instantiate() as MinimapMarker
		marker_layer.add_child(marker)
		_markers_by_id[marker_id] = marker
	var diameter: float = float(marker_data["diameter"])
	var tint: Color = marker_data["color"]
	marker.configure(marker_data["icon"] as Texture2D, tint, diameter)
	var delta: Vector2 = SectorSpace.shortest_delta(player.global_position, target.global_position)
	var normalized_distance: float = minf(delta.length() / maxf(map_range, 1.0), 1.0)
	var direction: Vector2 = Vector2.RIGHT
	if delta.length_squared() > 0.001:
		direction = delta.normalized()
	marker.position = center + direction * radius * normalized_distance - marker.size * 0.5


func _clear_markers() -> void:
	for marker_value: Variant in _markers_by_id.values():
		var marker: MinimapMarker = marker_value as MinimapMarker
		marker.queue_free()
	_markers_by_id.clear()
