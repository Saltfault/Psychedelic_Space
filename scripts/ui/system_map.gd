extends Control
## Builds a seeded FTL route graph, draws it, and permits travel only along legal outgoing links.
class_name SystemMap

## Emitted after the player selects a legal outgoing edge; the coordinator performs the transition.
signal travel_requested(node_id: String)

const MIN_INTERMEDIATE_NODES: int = 10
const MAX_INTERMEDIATE_NODES: int = 14
const LINK_RADIUS: float = 18.0
const MAP_CONTENT_INSET: Vector2 = Vector2(72.0, 80.0)
const MAP_CONTENT_BOTTOM_RESERVED: float = 220.0
const ROUTE_VISUAL_SCENE: PackedScene = preload("res://scenes/ui/system_map_route.tscn")
const NODE_VISUAL_SCENE: PackedScene = preload("res://scenes/ui/system_map_node.tscn")
const ICON_START: Texture2D = preload("res://assets/ui/map_icons/sector_node.svg")
const ICON_GENERIC: Texture2D = preload("res://assets/ui/map_icons/sector_node.svg")
const ICON_ASTEROID: Texture2D = preload("res://assets/ui/map_icons/planet_pack/Asteroid.png")
const ICON_STATION: Texture2D = preload("res://assets/ui/map_icons/planet_pack/Tech.png")
const ICON_OUTPOST: Texture2D = preload("res://assets/ui/map_icons/planet_pack/Tech2.png")
const ICON_GATE: Texture2D = preload("res://assets/ui/map_icons/planet_pack/BlackHole.png")
const ICON_NEBULA: Texture2D = preload("res://assets/ui/map_icons/planet_pack/Clouds.png")
const ICON_ENEMY: Texture2D = preload("res://assets/ui/map_icons/enemy.svg")

@onready var info: Label = $Info
@onready var legend: Label = $Legend
@onready var close_button: Button = $CloseButton
@onready var background: Control = $Background
@onready var system_icon: TextureRect = $SystemHeader/SystemIcon
@onready var system_name: Label = $SystemHeader/SystemName
@onready var map_visuals: Node2D = $MapVisuals

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var nodes_by_id: Dictionary = { }
var node_order: Array[String] = []
var outgoing_links: Dictionary = { }
var current_node_id: String = ""
var start_node_id: String = ""
var warp_node_id: String = ""
var map_seed: int = 0


func _ready() -> void:
	add_to_group("system_map")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	legend.text = "START / SECTOR | ENEMY | STATION | NEBULA | ASTEROID RING\nOUTPOST | WARP GATE | PLANET / MOON / STAR ONLY WHEN PRESENT"
	close_button.pressed.connect(close_map)


## Deterministically create this run's graph, unique node IDs, and per-node sector seeds.
func generate_new_map(seed_value: int) -> void:
	map_seed = seed_value
	rng.seed = seed_value
	nodes_by_id.clear()
	node_order.clear()
	outgoing_links.clear()

	start_node_id = "node_start"
	warp_node_id = "node_warp"
	var start_position: Vector2 = Vector2(0.05, rng.randf_range(0.2, 0.8))
	var warp_position: Vector2 = Vector2(0.95, 0.95)
	var occupied_positions: Array[Vector2] = [start_position, warp_position]
	_add_node(start_node_id, start_position, "start", 0)
	var intermediate_count: int = rng.randi_range(MIN_INTERMEDIATE_NODES, MAX_INTERMEDIATE_NODES)
	var intermediate_ids: Array[String] = []
	for index in range(intermediate_count):
		var node_id: String = "node_%02d" % index
		var map_position: Vector2 = _random_intermediate_position(occupied_positions)
		occupied_positions.append(map_position)
		intermediate_ids.append(node_id)
		_add_node(node_id, map_position, "generic", index + 1)

	_add_node(warp_node_id, warp_position, "warp", intermediate_count + 1)
	intermediate_ids.sort_custom(_sort_nodes_by_x)

	node_order.append(start_node_id)
	node_order.append_array(intermediate_ids)
	node_order.append(warp_node_id)
	for node_id in node_order:
		outgoing_links[node_id] = []
	for index in range(node_order.size() - 1):
		_add_link(node_order[index], node_order[index + 1])

	for source_index in range(node_order.size() - 2):
		var source_id: String = node_order[source_index]
		var candidates: Array[Dictionary] = []
		var source_position: Vector2 = nodes_by_id[source_id]["map_position"]
		for candidate_index in range(source_index + 1, node_order.size()):
			var candidate_id: String = node_order[candidate_index]
			var candidate_position: Vector2 = nodes_by_id[candidate_id]["map_position"]
			candidates.append(
				{
					"id": candidate_id,
					"distance": source_position.distance_squared_to(candidate_position),
				}
			)
		candidates.sort_custom(_sort_candidates_by_distance)
		var extra_link_count: int = rng.randi_range(1, 2)
		for candidate_index in range(mini(extra_link_count, candidates.size())):
			_add_link(source_id, String(candidates[candidate_index]["id"]))

	nodes_by_id[node_order[1]]["role"] = "patrol"
	nodes_by_id[node_order[2]]["role"] = "nebula"
	nodes_by_id[node_order[3]]["role"] = "station"
	# The main objective is a point of interest on an ordinary sector, not its sector role.
	nodes_by_id[node_order[4]]["role"] = "patrol"
	nodes_by_id[node_order[4]]["has_outpost"] = true
	for index in range(5, node_order.size() - 1):
		var role_roll: float = rng.randf()
		if role_roll < 0.16:
			nodes_by_id[node_order[index]]["role"] = "asteroid_ring"
		elif role_roll < 0.31:
			nodes_by_id[node_order[index]]["role"] = "planet"
		elif role_roll < 0.41:
			nodes_by_id[node_order[index]]["role"] = "moon"
		elif role_roll < 0.48:
			nodes_by_id[node_order[index]]["role"] = "star"
		elif role_roll < 0.72:
			nodes_by_id[node_order[index]]["role"] = "patrol"
	var has_asteroid_ring: bool = false
	for index in range(5, node_order.size() - 1):
		if String(nodes_by_id[node_order[index]]["role"]) == "asteroid_ring":
			has_asteroid_ring = true
			break
	if not has_asteroid_ring and node_order.size() > 6:
		var ring_index: int = rng.randi_range(5, node_order.size() - 2)
		nodes_by_id[node_order[ring_index]]["role"] = "asteroid_ring"
	# A solar system has one physical star. Multiple star-role nodes were reusing
	# the same star definition and made Sol appear to contain several suns.
	var star_node_ids: Array[String] = []
	for index in range(5, node_order.size() - 1):
		var candidate_id: String = node_order[index]
		if String(nodes_by_id[candidate_id]["role"]) == "star":
			star_node_ids.append(candidate_id)
	if star_node_ids.is_empty():
		var star_index: int = rng.randi_range(5, node_order.size() - 2)
		var generated_star_id: String = node_order[star_index]
		nodes_by_id[generated_star_id]["role"] = "star"
		star_node_ids.append(generated_star_id)
	var retained_star_id: String = star_node_ids[rng.randi_range(0, star_node_ids.size() - 1)]
	for candidate_id in star_node_ids:
		if candidate_id != retained_star_id:
			nodes_by_id[candidate_id]["role"] = "generic"

	var system: SolarSystemDefinition = RunState.get_current_system()
	if system == null:
		Log.error("Current solar system YARD definition is missing", RunState.current_system_id)
		return
	for node_id in node_order:
		var node_data: Dictionary = nodes_by_id[node_id]
		node_data["solar_system_id"] = String(system.system_id)
		node_data["solar_system_name"] = system.display_name
		node_data["solar_system_attributes"] = {
			"asteroid_cluster_minimum": system.asteroid_clusters,
			"asteroid_cluster_maximum": system.asteroid_clusters + 2,
			"nebula_chance": system.nebula_chance,
		}
		node_data["planet_id"] = ""
		var role: String = String(node_data["role"])
		if role in ["planet", "moon", "star"]:
			var body_kind: int = _body_kind_for_role(role)
			var matching_planets: Array[PlanetDefinition] = []
			for candidate: PlanetDefinition in system.planets:
				if int(candidate.body_kind) == body_kind:
					matching_planets.append(candidate)
			if matching_planets.is_empty():
				Log.error("Solar system has no PlanetDefinition for generated body role", system.system_id, role)
				node_data["role"] = "generic"
				continue
			var planet: PlanetDefinition = matching_planets[rng.randi_range(0, matching_planets.size() - 1)]
			node_data["planet_id"] = String(planet.planet_id)
			node_data["planet_kind"] = int(planet.body_kind)
	system_name.text = system.display_name
	system_icon.texture = system.map_icon

	current_node_id = start_node_id
	_refresh_graph_visuals()


## Find the nearest matching sector/system or add a debug destination connected to the current node.
func debug_find_or_create_node(kind: String, target: String) -> String:
	var wanted_kind: String = kind.to_lower()
	var wanted_target: String = target.to_lower()
	var origin_data: Dictionary = nodes_by_id.get(current_node_id, {})
	var origin_position: Vector2 = origin_data.get("map_position", Vector2(0.5, 0.5))
	var nearest_id: String = ""
	var nearest_distance: float = INF

	for candidate_id in node_order:
		var candidate: Dictionary = nodes_by_id[candidate_id]
		var matches: bool = false
		if wanted_kind == "sector":
			matches = (
				bool(candidate.get("has_outpost", false))
				if wanted_target == "outpost"
				else String(candidate.get("role", "")).to_lower() == wanted_target
			)
		elif wanted_kind == "system":
			matches = String(candidate.get("solar_system_id", "")).to_lower() == wanted_target
		if matches:
			var candidate_position: Vector2 = candidate.get("map_position", Vector2.ZERO)
			var candidate_distance: float = origin_position.distance_squared_to(candidate_position)
			if candidate_distance < nearest_distance:
				nearest_distance = candidate_distance
				nearest_id = candidate_id

	if not nearest_id.is_empty():
		return nearest_id

	var role: String = wanted_target if wanted_kind == "sector" else "generic"
	var adds_outpost: bool = wanted_kind == "sector" and wanted_target == "outpost"
	if adds_outpost:
		role = "patrol"
	var node_id: String = "debug_node_%d" % nodes_by_id.size()
	while nodes_by_id.has(node_id):
		node_id += "_new"
	var occupied_positions: Array[Vector2] = []
	for existing_id in node_order:
		var existing_data: Dictionary = nodes_by_id[existing_id]
		occupied_positions.append(existing_data.get("map_position", Vector2.ZERO))
	var new_position: Vector2 = _random_intermediate_position(occupied_positions)
	_add_node(node_id, new_position, role, nodes_by_id.size())
	nodes_by_id[node_id]["has_outpost"] = adds_outpost
	if wanted_kind == "system":
		nodes_by_id[node_id]["solar_system_id"] = wanted_target
	outgoing_links[node_id] = []
	if not outgoing_links.has(current_node_id):
		outgoing_links[current_node_id] = []
	_add_link(current_node_id, node_id)
	node_order.append(node_id)
	_refresh_graph_visuals()
	Log.info("Developer map destination created", wanted_kind, wanted_target, node_id)
	return node_id


## Set map focus for a dev teleport without applying the regular clear/link travel gates.
func debug_set_current_node(node_id: String) -> bool:
	if not nodes_by_id.has(node_id):
		return false
	current_node_id = node_id
	_refresh_graph_visuals()
	return true


func _add_node(node_id: String, map_position: Vector2, role: String, ordinal: int) -> void:
	nodes_by_id[node_id] = {
		"id": node_id,
		"map_position": map_position,
		"role": role,
		"generation_seed": absi(map_seed + ordinal * 7919),
		"solar_system_id": "generic_system",
		"solar_system_name": "Uncharted System",
		"solar_system_attributes": { },
		"planet_id": "",
		"planet_kind": int(PlanetDefinition.BodyKind.PLANET),
		"has_outpost": false,
	}


func _random_intermediate_position(occupied: Array[Vector2]) -> Vector2:
	# Keep randomly scattered dots readable instead of letting them overlap.
	for attempt in range(128):
		var candidate: Vector2 = Vector2(rng.randf_range(0.12, 0.87), rng.randf_range(0.08, 0.9))
		var is_clear: bool = true
		for other_position in occupied:
			if candidate.distance_to(other_position) < 0.075:
				is_clear = false
				break
		if is_clear:
			return candidate
	return Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.1, 0.88))


func _add_link(from_id: String, to_id: String) -> void:
	var links: Array = outgoing_links[from_id]
	if not links.has(to_id):
		links.append(to_id)
		outgoing_links[from_id] = links


func _sort_nodes_by_x(a: String, b: String) -> bool:
	return float(nodes_by_id[a]["map_position"].x) < float(nodes_by_id[b]["map_position"].x)


func _sort_candidates_by_distance(a: Dictionary, b: Dictionary) -> bool:
	return float(a["distance"]) < float(b["distance"])


## Return whether the sector is clear and node_id is a legal outgoing edge.
func can_travel_to_node(node_id: String) -> bool:
	# Required local objectives and hostile ships must be resolved before route travel is enabled.
	if not RunState.current_sector_clear:
		return false
	if not outgoing_links.has(current_node_id):
		return false
	return node_id in outgoing_links[current_node_id]


## Return an isolated copy of a node record, or an empty dictionary for an unknown ID.
func get_node_data(node_id: String) -> Dictionary:
	var node_data: Dictionary = nodes_by_id.get(node_id, {})
	return node_data.duplicate(true)


## Commit a legal outgoing route and return false without changing the map otherwise.
func commit_travel(node_id: String) -> bool:
	if not can_travel_to_node(node_id):
		return false

	current_node_id = node_id
	_refresh_graph_visuals()
	return true


## Display the map and pause gameplay until the player closes it or chooses a route.
func open_map() -> void:
	_refresh_info()
	show()
	get_tree().paused = true


## Hide the map and resume the scene tree.
func close_map() -> void:
	hide()
	get_tree().paused = false


func _gui_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		return
	var clicked_id: String = _node_at(event.position)
	if clicked_id.is_empty() or not can_travel_to_node(clicked_id):
		return
	hide()
	get_tree().paused = false
	travel_requested.emit(clicked_id)
	accept_event()


func _node_at(mouse_position: Vector2) -> String:
	for node_id in node_order:
		if _screen_position(node_id).distance_to(mouse_position) <= LINK_RADIUS:
			return node_id
	return ""


func _screen_position(node_id: String) -> Vector2:
	# Keep generated routes inside the user's smaller framed map, above its footer labels.
	var bounds: Rect2 = Rect2(
		background.position + MAP_CONTENT_INSET,
		background.size - Vector2(
			MAP_CONTENT_INSET.x * 2.0,
			MAP_CONTENT_INSET.y + MAP_CONTENT_BOTTOM_RESERVED,
		)
	)
	return bounds.position + nodes_by_id[node_id]["map_position"] * bounds.size


func _refresh_graph_visuals() -> void:
	# Visuals are authored in packed scenes; this method only positions and configures them.
	for child: Node in map_visuals.get_children():
		child.queue_free()
	for from_id in node_order:
		for to_value: Variant in outgoing_links.get(from_id, []):
			var to_id: String = String(to_value)
			var route: SystemMapRouteVisual = ROUTE_VISUAL_SCENE.instantiate() as SystemMapRouteVisual
			map_visuals.add_child(route)
			var tint: Color = Color(0.45, 0.9, 1.0, 1.0) if from_id == current_node_id else Color(0.25, 0.55, 0.72, 0.85)
			route.configure(_screen_position(from_id), _screen_position(to_id), tint)
	for node_id in node_order:
		var node_data: Dictionary = nodes_by_id[node_id]
		var node_role: String = String(nodes_by_id[node_id]["role"])
		var marker: SystemMapNodeVisual = NODE_VISUAL_SCENE.instantiate() as SystemMapNodeVisual
		map_visuals.add_child(marker)
		marker.position = _screen_position(node_id)
		var selected: bool = node_id == current_node_id
		var caption: String = node_role.to_upper() if node_role in ["start", "warp"] else ""
		if node_role == "asteroid_ring":
			caption = "ASTEROID RING"
		marker.configure(
			_node_icon(node_data),
			selected,
			selected or can_travel_to_node(node_id),
			caption,
			bool(node_data.get("has_outpost", false)) and not RunState.outpost_destroyed,
		)


func _body_kind_for_role(role: String) -> int:
	match role:
		"planet": return PlanetDefinition.BodyKind.PLANET
		"moon": return PlanetDefinition.BodyKind.MOON
		"star": return PlanetDefinition.BodyKind.STAR
		_: return PlanetDefinition.BodyKind.PLANET


func _node_icon(node_data: Dictionary) -> Texture2D:
	var role: StringName = StringName(str(node_data.get("role", "generic")))
	var planet_id: StringName = StringName(str(node_data.get("planet_id", "")))
	if planet_id != &"":
		var planet: PlanetDefinition = RunState.get_planet(planet_id)
		if planet != null:
			return planet.map_icon if planet.map_icon != null else ICON_GENERIC
	# A missing or invalid definition must never draw a pretend planet, moon, or star.
	if role in [&"planet", &"moon", &"star"]:
		return ICON_GENERIC
	var icon: Texture2D = _role_icon(role)
	if icon == null:
		icon = ICON_GENERIC
	return icon


func _role_icon(role: StringName) -> Texture2D:
	match role:
		&"start": return ICON_START
		&"generic": return ICON_GENERIC
		&"asteroid_ring": return ICON_ASTEROID
		&"patrol": return ICON_ENEMY
		&"nebula": return ICON_NEBULA
		&"station": return ICON_STATION
		&"outpost": return ICON_OUTPOST
		&"warp": return ICON_GATE
		_: return null


func _refresh_info() -> void:
	var node_data: Dictionary = get_node_data(current_node_id)
	info.text = "Tick %d | %s (%s) | Sector %s\nOutpost: %s | Intel: %s\nCaravan last known: %s" % [
		RunState.world_tick,
		current_node_id,
		String(node_data.get("role", "unknown")).to_upper(),
		"CLEAR" if RunState.current_sector_clear else "UNCLEARED",
		"complete" if RunState.main_objective_complete else "active",
		(
			"complete"
			if RunState.side_objective_complete
			else ("lost" if RunState.side_objective_expired else "active")
		),
		RunState.known_caravan_sector.to_upper(),
	]
