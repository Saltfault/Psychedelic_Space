extends Node2D
class_name SectorRoot

@export var sector_id: String = "start"
@export var sector_size: Vector2 = Vector2(8000.0, 8000.0)
@export var spawn_position: Vector2 = Vector2(4000.0, 4000.0)

@export var caravan_scene: PackedScene
@export var caravan_spawn_position: Vector2 = Vector2(2500.0, 2500.0)

@export var reinforcement_enemy_scene: PackedScene
@export var reinforcement_positions: Array[Vector2] = []


func _ready() -> void:
	SectorSpace.sector_size = sector_size

	_handle_persistent_objectives()
	_spawn_caravan_if_present()
	_spawn_outpost_reinforcements()


func get_spawn_position() -> Vector2:
	return spawn_position


func _handle_persistent_objectives() -> void:
	if sector_id == "outpost" and RunState.outpost_destroyed:
		var objective := get_tree().get_first_node_in_group("main_objective")
		if objective != null and is_ancestor_of(objective):
			objective.queue_free()


func _spawn_caravan_if_present() -> void:
	if caravan_scene == null:
		return

	if RunState.get_actual_caravan_sector() != sector_id:
		return

	var caravan = caravan_scene.instantiate()
	caravan.global_position = caravan_spawn_position
	add_child(caravan)


func _spawn_outpost_reinforcements() -> void:
	if sector_id != "outpost":
		return

	if reinforcement_enemy_scene == null:
		return

	var count := min(RunState.outpost_reinforcement_level, reinforcement_positions.size())

	for i in range(count):
		var enemy = reinforcement_enemy_scene.instantiate()
		enemy.global_position = reinforcement_positions[i]
		add_child(enemy)
