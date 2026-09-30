extends Node
## Builds deterministic sector content by composing reusable encounters and landmarks.
class_name SectorGenerator

## Patrol encounter scene used by roles that guarantee combat activity.
@export var patrol_group_scene: PackedScene
## Optional station landmark used in station-role sectors.
@export var station_scene: PackedScene
## Interactive sensor-interference field used in nebula-role sectors.
@export var nebula_scene: PackedScene
## Side-objective beacon used in nebula-role sectors.
@export var intel_beacon_scene: PackedScene
## Main objective structure used in outpost-role sectors.
@export var outpost_scene: PackedScene
## Projectile dependency assigned to generated outposts before they enter the tree.
@export var projectile_scene: PackedScene
## Animated physical exit gate instantiated in the final warp sector.
@export var warp_gate_scene: PackedScene

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var reserved_positions: Array[Vector2] = []


## Populate the supplied generated sector deterministically from its role, seed, and system attributes.
func generate_sector(sector: SectorRoot) -> void:
	# The node seed makes this layout stable when the player leaves and returns.
	rng.seed = sector.sector_seed
	reserved_positions.clear()
	sector.reinforcement_positions.clear()
	if RunState.get_actual_caravan_sector() == sector.sector_id:
		# Leave a clear arrival pocket for the persistent caravan instance.
		reserved_positions.append(sector.caravan_spawn_position)
	_generate_asteroids(sector)

	# Each role guarantees its mission-critical actors; all positions remain seeded.
	match sector.sector_id:
		"start":
			_spawn_patrol(sector, _random_open_position(sector))
		"patrol":
			_spawn_patrol(sector, _random_open_position(sector))
			_spawn_patrol(sector, _random_open_position(sector))
		"station":
			_spawn_sensor_area(
				station_scene,
				sector.get_node("Landmarks"),
				_random_open_position(sector, 800.0, 950.0),
			)
			_spawn_patrol(sector, _random_open_position(sector))
		"nebula":
			_spawn_nebula_objective(sector)
			_spawn_patrol(sector, _random_open_position(sector))
		"outpost":
			_spawn_outpost(sector, _random_open_position(sector, 900.0, 1050.0))
			_spawn_patrol(sector, _random_open_position(sector))
			for index in range(3):
				var reinforcement_position: Vector2 = _random_open_position(sector)
				sector.reinforcement_positions.append(reinforcement_position)
				reserved_positions.append(reinforcement_position)
		"warp":
			_spawn_patrol(sector, _random_open_position(sector))
			_spawn_patrol(sector, _random_open_position(sector))
			if warp_gate_scene != null:
				_spawn_scene(
					warp_gate_scene,
					sector.get_node("Landmarks"),
					_random_open_position(sector, 600.0, 3000.0),
				)
		_:
			# Generic nodes vary between quiet travel and a small patrol encounter.
			var patrol_count: int = rng.randi_range(0, 2)
			for index in range(patrol_count):
				_spawn_patrol(sector, _random_open_position(sector))


func _generate_asteroids(sector: SectorRoot) -> void:
	# Reserve each cluster and build several matching visual/collision rocks inside it.
	var cluster_minimum: int = maxi(0, int(_system_attribute(sector, &"asteroid_cluster_minimum", 4)))
	var cluster_maximum: int = maxi(cluster_minimum, int(_system_attribute(sector, &"asteroid_cluster_maximum", 9)))
	var cluster_count: int = rng.randi_range(cluster_minimum, cluster_maximum)
	if sector.sector_id == "start":
		cluster_count = rng.randi_range(2, 4)
	for cluster_index in range(cluster_count):
		var cluster_position: Vector2 = _random_open_position(sector, 850.0)
		reserved_positions.append(cluster_position)
		var rocks_in_cluster: int = rng.randi_range(2, 5)
		for rock_index in range(rocks_in_cluster):
			var rock: StaticBody2D = StaticBody2D.new()
			var visual: Polygon2D = Polygon2D.new()
			var collision: CollisionPolygon2D = CollisionPolygon2D.new()
			var points: PackedVector2Array = _make_rock_polygon()
			visual.polygon = points
			visual.color = Color(
				rng.randf_range(0.16, 0.3),
				rng.randf_range(0.18, 0.32),
				rng.randf_range(0.26, 0.42),
				1.0,
			)
			collision.polygon = points
			rock.add_child(visual)
			rock.add_child(collision)
			sector.get_node("Asteroids").add_child(rock)
			var rock_position: Vector2 = cluster_position + Vector2(
				rng.randf_range(-160.0, 160.0),
				rng.randf_range(-160.0, 160.0),
			)
			rock_position.x = clampf(rock_position.x, 200.0, sector.sector_size.x - 200.0)
			rock_position.y = clampf(rock_position.y, 200.0, sector.sector_size.y - 200.0)
			rock.position = rock_position
			rock.rotation = rng.randf_range(0.0, TAU)
			# Later landmarks test against each rock, not just its cluster center.
			reserved_positions.append(rock_position)


func _make_rock_polygon() -> PackedVector2Array:
	# Radially varied vertices give each collidable asteroid a distinct silhouette.
	var points: PackedVector2Array = PackedVector2Array()
	var vertex_count: int = rng.randi_range(7, 11)
	for index in range(vertex_count):
		var angle: float = TAU * float(index) / float(vertex_count)
		var radius: float = rng.randf_range(55.0, 175.0)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _spawn_nebula_objective(sector: SectorRoot) -> void:
	# Keep the beacon near the nebula while avoiding a direct overlap with its center.
	var nebula_position: Vector2 = _random_open_position(sector, 2500.0, 3000.0)
	_spawn_scene(nebula_scene, sector.get_node("Landmarks"), nebula_position)
	var beacon_position: Vector2 = nebula_position + Vector2(950.0, 250.0)
	beacon_position.x = clampf(beacon_position.x, 250.0, sector.sector_size.x - 250.0)
	beacon_position.y = clampf(beacon_position.y, 250.0, sector.sector_size.y - 250.0)
	_spawn_sensor_area(intel_beacon_scene, sector.get_node("Landmarks"), beacon_position)


func _system_attribute(sector: SectorRoot, key: StringName, fallback: Variant) -> Variant:
	# Until solar-system generation exists, empty attributes use neutral prototype values.
	return sector.solar_system_attributes.get(key, fallback)


func _spawn_outpost(sector: SectorRoot, at: Vector2) -> void:
	# Assign its weapon before adding it so the firing timer never sees an unset scene.
	if outpost_scene == null:
		Log.error("Generated outpost is not configured on SectorGenerator", sector.sector_id)
		return
	var outpost: Outpost = outpost_scene.instantiate() as Outpost
	if outpost == null:
		Log.error("Configured outpost scene is not an Outpost", outpost_scene.resource_path)
		return
	outpost.projectile_scene = projectile_scene
	outpost.position = at
	sector.get_node("Landmarks").add_child(outpost)
	reserved_positions.append(at)
	Log.info("Generated enemy outpost", sector.map_node_id, at)


func _spawn_sensor_area(scene: PackedScene, parent: Node, at: Vector2) -> void:
	# Station and IntelBeacon must monitor the PlayerShip's physics layer (2).
	if scene == null:
		Log.error("Required sector landmark scene is not configured", parent.name)
		return
	var area: Area2D = scene.instantiate() as Area2D
	if area == null:
		Log.error("Configured sensor landmark is not an Area2D", scene.resource_path)
		return
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = at
	parent.add_child(area)
	reserved_positions.append(at)
	Log.info("Generated sector landmark", scene.resource_path, at)


func _spawn_patrol(sector: SectorRoot, at: Vector2) -> void:
	# Encounters use the existing authored group with its distinct ship sprites.
	_spawn_scene(patrol_group_scene, sector.get_node("Encounters"), at)


func _spawn_scene(scene: PackedScene, parent: Node, at: Vector2) -> void:
	# Missing optional content is skipped safely until its guide step creates it.
	if scene == null:
		return
	var instance: Node2D = scene.instantiate() as Node2D
	if instance == null:
		return
	instance.position = at
	parent.add_child(instance)
	reserved_positions.append(at)


func _random_open_position(
	sector: SectorRoot,
	clearance: float = 600.0,
	minimum_spawn_distance: float = 1600.0,
) -> Vector2:
	# Bounded attempts avoid spawning a landmark on the player, a rock, or another actor.
	for attempt in range(96):
		var candidate: Vector2 = Vector2(
			rng.randf_range(250.0, sector.sector_size.x - 250.0),
			rng.randf_range(250.0, sector.sector_size.y - 250.0),
		)
		if candidate.distance_to(sector.spawn_position) < minimum_spawn_distance:
			continue
		var blocked: bool = false
		for reserved in reserved_positions:
			if candidate.distance_to(reserved) < clearance:
				blocked = true
				break
		if not blocked:
			return candidate
	# Failed random placement must not hide required content on the far edge of the sector.
	var fallback_radius: float = maxf(minimum_spawn_distance + 150.0, clearance + 250.0)
	for index in range(16):
		var angle: float = TAU * float(index) / 16.0
		var fallback: Vector2 = sector.spawn_position + Vector2.RIGHT.rotated(angle) * fallback_radius
		fallback.x = clampf(fallback.x, 250.0, sector.sector_size.x - 250.0)
		fallback.y = clampf(fallback.y, 250.0, sector.sector_size.y - 250.0)
		var blocked: bool = false
		for reserved in reserved_positions:
			if fallback.distance_to(reserved) < clearance:
				blocked = true
				break
		if not blocked:
			return fallback
	return sector.spawn_position + Vector2(fallback_radius, 0.0)
