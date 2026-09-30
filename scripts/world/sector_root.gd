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

## Optional persistent caravan scene spawned only in its current route sector.
@export var caravan_scene: PackedScene
## Local spawn point used by the persistent caravan instance.
@export var caravan_spawn_position: Vector2 = Vector2(2500.0, 2500.0)

## Enemy scene used for persistent outpost reinforcements.
@export var reinforcement_enemy_scene: PackedScene
## Deterministic positions generated for the outpost's current reinforcement level.
@export var reinforcement_positions: Array[Vector2] = []

## The map node identity and seed configure campaign-generated sector content.
@onready var sector_generator: Node = get_node_or_null("SectorGenerator")

var map_node_id: String = ""
var sector_seed: int = 0
var solar_system_id: String = "generic_system"
var solar_system_attributes: Dictionary = {}
## Current route-clear result, derived from this sector's required objective and live enemies.
var is_clear: bool:
	get:
		return _mandatory_objectives_resolved() and _living_enemy_count() == 0

var _last_published_clear_state: bool = false


## Apply map data before adding this scene to the active scene tree.
func configure_for_map_node(node_data: Dictionary) -> void:
	map_node_id = String(node_data.get("id", ""))
	sector_id = String(node_data.get("role", "generic"))
	sector_seed = int(node_data.get("generation_seed", 0))
	solar_system_id = String(node_data.get("solar_system_id", "generic_system"))
	var raw_attributes: Variant = node_data.get("solar_system_attributes", {})
	if raw_attributes is Dictionary:
		solar_system_attributes = raw_attributes.duplicate(true)
	else:
		solar_system_attributes.clear()


func _ready() -> void:
	SectorSpace.sector_size = sector_size
	# Authored Section 23 fixtures have no generator; leave their layouts untouched.
	if sector_generator != null and sector_generator.has_method("generate_sector"):
		sector_generator.call("generate_sector", self)

	_handle_persistent_objectives()
	_spawn_caravan_if_present()
	_spawn_outpost_reinforcements()

	if not RunState.run_state_changed.is_connected(_refresh_clear_state):
		RunState.run_state_changed.connect(_refresh_clear_state)
	_connect_enemy_death_signals()
	_last_published_clear_state = is_clear


## Return whether this sector's role objective is resolved and no hostile ships remain.
func _mandatory_objectives_resolved() -> bool:
	match sector_id:
		"outpost":
			return RunState.main_objective_complete
		# Intel is optional; blocking departure would prevent its world-tick deadline from advancing.
		_:
			return true


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


func _handle_persistent_objectives() -> void:
	if sector_id == "outpost" and RunState.outpost_destroyed:
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
	caravan.global_position = caravan_spawn_position
	add_child(caravan)


func _spawn_outpost_reinforcements() -> void:
	if sector_id != "outpost":
		return

	if reinforcement_enemy_scene == null:
		return

	var count: int = mini(RunState.outpost_reinforcement_level, reinforcement_positions.size())

	for i in range(count):
		var enemy: Node2D = reinforcement_enemy_scene.instantiate() as Node2D
		if enemy == null:
			continue
		enemy.global_position = reinforcement_positions[i]
		add_child(enemy)
