extends Node2D
## Owns a sector's bounds, generated content, and persistent actors restored for this visit.
class_name SectorRoot

## Emitted when this sector transitions between uncleared and cleared.
signal clear_state_changed(is_clear: bool)

## Semantic role used by mission logic and deterministic sector generation.
@export var sector_id: String = "start"
## World-space dimensions shared with SectorSpace for wrapped movement and queries.
@export var sector_size: Vector2 = Vector2(8000.0, 8000.0)
## Player arrival point and exclusion center for generated actor placement.
@export var spawn_position: Vector2 = Vector2(4000.0, 4000.0)

## Extra pixels beyond the spawn clearance floor used by caravan/reinforcement arrivals.
const OFFMAP_SPAWN_MARGIN: float = 150.0

## Optional persistent caravan scene spawned only in its current route sector.
@export var caravan_scene: PackedScene
## Arrival-relative offset reserved for the persistent caravan's three-ship formation.
@export var caravan_spawn_offset: Vector2 = Vector2(250.0, 0.0)

## Enemy scene used for persistent outpost reinforcements.
@export var reinforcement_enemy_scene: PackedScene
## Scene-authored sector positions used as deterministic reinforcement spawn slots.
@export var reinforcement_spawn_positions: Array[Vector2] = []
## The map node identity and seed configure campaign-generated sector content.
@onready var sector_generator: Node = get_node_or_null("SectorGenerator")

var map_node_id: String = ""
var sector_seed: int = 0
## Restoring an already-cleared visit skips regenerated hostiles so its clear state remains true.
var skip_hostile_spawns: bool = false
var solar_system_id: String = "generic_system"
var solar_system_name: String = "Uncharted System"
var solar_system_attributes: Dictionary = {}
## Stable YARD key selected for this route node's body; empty means no body.
var planet_id: StringName = &""
## BodyKind ordinal serialized into procedural route data.
var planet_kind: int = PlanetDefinition.BodyKind.PLANET
## Whether this route node contains the campaign outpost objective, independent of sector role.
var has_outpost_objective: bool = false
## Clear requires resolved objectives, no live enemies, and no future hostile waves.
var is_clear: bool:
	get:
		return (
			_mandatory_objectives_resolved()
			and _living_enemy_count() == 0
			and (sector_generator == null or int(sector_generator.get("waves_remaining")) == 0)
		)

var _last_published_clear_state: bool = false


## Apply map data before adding this scene to the active scene tree.
func configure_for_map_node(node_data: Dictionary) -> void:
	map_node_id = String(node_data.get("id", ""))
	sector_id = String(node_data.get("role", "generic"))
	sector_seed = int(node_data.get("generation_seed", 0))
	solar_system_id = String(node_data.get("solar_system_id", "generic_system"))
	solar_system_name = String(node_data.get("solar_system_name", "Uncharted System"))
	planet_id = StringName(str(node_data.get("planet_id", "")))
	planet_kind = int(node_data.get("planet_kind", PlanetDefinition.BodyKind.PLANET))
	has_outpost_objective = bool(node_data.get("has_outpost", false))
	var raw_attributes: Variant = node_data.get("solar_system_attributes", {})
	if raw_attributes is Dictionary:
		solar_system_attributes = raw_attributes.duplicate(true)
	else:
		solar_system_attributes.clear()


func _ready() -> void:
	SectorSpace.sector_size = sector_size
	# Apply persisted objective state before procedural content creates this visit's actors.
	_handle_persistent_objectives()
	# Authored Section 23 fixtures have no generator; leave their layouts untouched.
	if sector_generator != null and sector_generator.has_method("generate_sector"):
		sector_generator.call("generate_sector", self)

	_spawn_caravan_if_present()
	_spawn_outpost_reinforcements()

	if not RunState.run_state_changed.is_connected(_refresh_clear_state):
		RunState.run_state_changed.connect(_refresh_clear_state)
	_connect_enemy_death_signals()
	_last_published_clear_state = is_clear


## Return whether this sector's role objective is resolved and no hostile ships remain.
func _mandatory_objectives_resolved() -> bool:
	# Intel is optional; only the separately-marked outpost blocks sector travel.
	return not has_outpost_objective or RunState.main_objective_complete


func _living_enemy_count() -> int:
	# Inspect this sector's descendants directly: clear state is also queried while
	# a newly-instantiated sector is detached from the SceneTree.
	return _count_living_enemies(self)


func _count_living_enemies(parent: Node) -> int:
	var living_count: int = 0
	for child in parent.get_children():
		var enemy: BaseShip = child as BaseShip
		if enemy != null and (enemy.team != 0 or enemy.is_in_group("enemy_ship")) and not enemy.is_dead:
			living_count += 1
		living_count += _count_living_enemies(child)
	return living_count


func _connect_enemy_death_signals() -> void:
	# Traverse the sector itself so the same logic works during scene setup and in-tree.
	_connect_enemy_signals_under(self)


func _connect_enemy_signals_under(parent: Node) -> void:
	for child in parent.get_children():
		var enemy: BaseShip = child as BaseShip
		if enemy != null and (enemy.team != 0 or enemy.is_in_group("enemy_ship")):
			if not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)
			if not enemy.tree_exited.is_connected(_refresh_clear_state):
				enemy.tree_exited.connect(_refresh_clear_state)
		_connect_enemy_signals_under(child)


func _on_enemy_died(_enemy: BaseShip) -> void:
	# Wait until the death handler marks the ship dead and queues it for removal.
	call_deferred("_refresh_clear_state")


func _refresh_clear_state() -> void:
	var next_clear_state: bool = is_clear
	if next_clear_state == _last_published_clear_state:
		return
	_last_published_clear_state = next_clear_state
	clear_state_changed.emit(next_clear_state)
	Log.info("Sector clear state updated", map_node_id, sector_id, next_clear_state)


## Return this sector's arrival point for the run coordinator.
func get_spawn_position() -> Vector2:
	return spawn_position


## Resolve the required objective, stop future enemy waves, and remove all living hostiles.
## Returns the number of ships removed; normal clear-state signals remain authoritative.
func debug_complete_sector() -> int:
	skip_hostile_spawns = true
	if sector_generator != null and sector_generator.has_method("stop_enemy_waves"):
		sector_generator.call("stop_enemy_waves")

	if has_outpost_objective:
		var outposts: Array[Node] = find_children("*", "Outpost", true, false)
		for candidate in outposts:
			var outpost: Outpost = candidate as Outpost
			if outpost != null and outpost.hull > 0.0:
				outpost.take_damage(outpost.hull + outpost.shield + 1.0)
		if not RunState.main_objective_complete:
			# A missing objective must not leave a force-cleared sector locked.
			RunState.complete_main_objective()

	var hostiles: Array[BaseShip] = []
	_collect_living_hostiles(self, hostiles)
	for hostile: BaseShip in hostiles:
		hostile.take_damage(hostile.hull + hostile.shield + 1.0)

	_refresh_clear_state()
	return hostiles.size()


func _collect_living_hostiles(parent: Node, hostiles: Array[BaseShip]) -> void:
	for child in parent.get_children():
		var ship: BaseShip = child as BaseShip
		if ship != null and (ship.team != 0 or ship.is_in_group("enemy_ship")) and not ship.is_dead:
			hostiles.append(ship)
		_collect_living_hostiles(child, hostiles)


func _handle_persistent_objectives() -> void:
	if has_outpost_objective and RunState.outpost_destroyed:
		var objective: Node = get_tree().get_first_node_in_group("main_objective")
		if objective != null and is_ancestor_of(objective):
			objective.queue_free()


func _spawn_caravan_if_present() -> void:
	if caravan_scene == null:
		return

	if RunState.get_actual_caravan_sector() != sector_id:
		return

	var caravan: Node2D = caravan_scene.instantiate() as Node2D
	if caravan == null:
		return
	# Keep the convoy out of the minimap bubble: it travels in from the same
	# direction as caravan_spawn_offset, but from beyond the clearance floor.
	var convoy_direction: Vector2 = (
		caravan_spawn_offset.normalized()
		if caravan_spawn_offset.length_squared() > 0.001
		else Vector2.RIGHT
	)
	if sector_generator != null and sector_generator.has_method("enemy_spawn_distance"):
		var convoy_distance: float = (
			float(sector_generator.call("enemy_spawn_distance", self)) + OFFMAP_SPAWN_MARGIN
		)
		caravan.global_position = SectorSpace.wrap_position(
			spawn_position + convoy_direction * convoy_distance,
		)
	add_child(caravan)


func _spawn_outpost_reinforcements() -> void:
	if (
		not has_outpost_objective
		or skip_hostile_spawns
		or sector_id == "station"
		or RunState.outpost_destroyed
	):
		return

	if reinforcement_enemy_scene == null:
		return

	var count: int = clampi(
		RunState.outpost_reinforcement_level, 0, reinforcement_spawn_positions.size(),
	)
	if count == 0:
		return

	var player: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
	var spawn_distance: float = 1700.0
	var player_ship: PlayerShip = player as PlayerShip
	if is_instance_valid(player_ship):
		spawn_distance = maxf(spawn_distance, player_ship.sensor_range + 400.0)
	if sector_generator != null and sector_generator.has_method("enemy_spawn_distance"):
		spawn_distance = float(sector_generator.call("enemy_spawn_distance", self))
	for i in range(count):
		var enemy: Node2D = reinforcement_enemy_scene.instantiate() as Node2D
		if enemy == null:
			continue
		var reinforcement_position: Vector2 = reinforcement_spawn_positions[i]
		if is_instance_valid(player):
			var player_position: Vector2 = player.global_position
			var to_slot: Vector2 = SectorSpace.shortest_delta(player_position, reinforcement_position)
			var required_distance: float = spawn_distance + 120.0
			if to_slot.length() < required_distance:
				var direction: Vector2 = to_slot.normalized()
				if direction.length_squared() < 0.001:
					direction = Vector2.RIGHT.rotated(TAU * float(i) / float(count))
				reinforcement_position = SectorSpace.wrap_position(
					player_position + direction * required_distance,
				)
		# Use the authored slot unless it would violate the off-screen/sensor spawn floor.
		enemy.global_position = SectorSpace.wrap_position(reinforcement_position)
		add_child(enemy)
