extends Control
## Generates and draws the run's directed FTL graph and validates adjacent travel choices.
class_name SystemMap

## Emitted after the player selects a legal outgoing edge; the coordinator performs the transition.
signal travel_requested(node_id: String)

const MIN_INTERMEDIATE_NODES: int = 10
const MAX_INTERMEDIATE_NODES: int = 14
const LINK_RADIUS: float = 18.0
const MAP_CONTENT_INSET: Vector2 = Vector2(72.0, 80.0)
const MAP_CONTENT_BOTTOM_RESERVED: float = 220.0

@onready var info: Label = $Info
@onready var legend: Label = $Legend
@onready var close_button: Button = $CloseButton
@onready var background: Control = $Background

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var nodes_by_id: Dictionary = { }
var node_order: Array[String] = []
var outgoing_links: Dictionary = { }
var current_node_id: String = ""
var start_node_id: String = ""
var warp_node_id: String = ""
var map_seed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	legend.text = "START cyan | PATROL red | STATION green | NEBULA violet | OUTPOST amber | WARP gold | GENERIC blue-gray"
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
	nodes_by_id[node_order[4]]["role"] = "outpost"
	for index in range(5, node_order.size() - 1):
		if rng.randf() < 0.35:
			nodes_by_id[node_order[index]]["role"] = "patrol"

	current_node_id = start_node_id
	queue_redraw()


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
			matches = String(candidate.get("role", "")).to_lower() == wanted_target
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
	var node_id: String = "debug_node_%d" % nodes_by_id.size()
	while nodes_by_id.has(node_id):
		node_id += "_new"
	var occupied_positions: Array[Vector2] = []
	for existing_id in node_order:
		var existing_data: Dictionary = nodes_by_id[existing_id]
		occupied_positions.append(existing_data.get("map_position", Vector2.ZERO))
	var position: Vector2 = _random_intermediate_position(occupied_positions)
	_add_node(node_id, position, role, nodes_by_id.size())
	if wanted_kind == "system":
		nodes_by_id[node_id]["solar_system_id"] = wanted_target
	outgoing_links[node_id] = []
	if not outgoing_links.has(current_node_id):
		outgoing_links[current_node_id] = []
	_add_link(current_node_id, node_id)
	node_order.append(node_id)
	queue_redraw()
	Log.info("Developer map destination created", wanted_kind, wanted_target, node_id)
	return node_id


## Set map focus for a dev teleport without applying the regular clear/link travel gates.
func debug_set_current_node(node_id: String) -> bool:
	if not nodes_by_id.has(node_id):
		return false
	current_node_id = node_id
	queue_redraw()
	return true


func _add_node(node_id: String, map_position: Vector2, role: String, ordinal: int) -> void:
	nodes_by_id[node_id] = {
		"id": node_id,
		"map_position": map_position,
		"role": role,
		"generation_seed": absi(map_seed + ordinal * 7919),
		"solar_system_id": "generic_system",
		"solar_system_attributes": { },
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
	queue_redraw()
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


func _draw() -> void:
	# Links first, then role-specific dots so every route is easy to read.
	for from_id in node_order:
		for to_id in outgoing_links.get(from_id, []):
			var line_color: Color = Color(0.25, 0.55, 0.72, 0.85)
			if from_id == current_node_id:
				line_color = Color(0.45, 0.9, 1.0, 1.0)
			_draw_route_link(_screen_position(from_id), _screen_position(String(to_id)), line_color)
	for node_id in node_order:
		var node_role: String = String(nodes_by_id[node_id]["role"])
		var dot_color: Color = _role_color(node_role)
		if node_id == current_node_id:
			dot_color = Color.WHITE
		elif not can_travel_to_node(node_id):
			dot_color.a = 0.38
		draw_circle(
			_screen_position(node_id),
			10.0 if node_id != current_node_id else 14.0,
			dot_color,
		)
		if node_role == "start" or node_role == "warp":
			draw_string(
				ThemeDB.fallback_font,
				_screen_position(node_id) + Vector2(14.0, 5.0),
				node_role.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				16,
				Color.WHITE,
			)


func _role_color(role: String) -> Color:
	match role:
		"start":
			return Color(0.45, 0.9, 1.0)
		"patrol":
			return Color(1.0, 0.32, 0.3)
		"station":
			return Color(0.35, 1.0, 0.58)
		"nebula":
			return Color(0.78, 0.42, 1.0)
		"outpost":
			return Color(1.0, 0.68, 0.25)
		"warp":
			return Color(1.0, 0.92, 0.55)
		_:
			return Color(0.64, 0.72, 0.82)


func _draw_route_link(from_position: Vector2, to_position: Vector2, color: Color) -> void:
	# Arrowheads make the map's forward-only travel rule visible at a glance.
	draw_line(from_position, to_position, color, 3.0, true)
	var direction: Vector2 = (to_position - from_position).normalized()
	var perpendicular: Vector2 = direction.orthogonal()
	var arrow_tip: Vector2 = to_position - direction * 13.0
	draw_line(arrow_tip, arrow_tip - direction * 10.0 + perpendicular * 6.0, color, 3.0, true)
	draw_line(arrow_tip, arrow_tip - direction * 10.0 - perpendicular * 6.0, color, 3.0, true)


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
