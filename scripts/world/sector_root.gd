extends Node2D
## Owns a sector's bounds, generated content, and persistent actors restored for this visit.
class_name SectorRoot

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


## Return the arrival point used by the run coordinator when entering this sector.
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
