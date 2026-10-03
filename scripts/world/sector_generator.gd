extends Node
## Builds deterministic sector content by composing reusable encounters and landmarks.
class_name SectorGenerator

const ASTEROID_SCRIPT: Script = preload("res://scripts/world/asteroid.gd")
const ASTEROID_CLEARANCE: float = 48.0
const MINIMAP_SPAWN_CLEARANCE: float = 1600.0
const ASTEROID_RING_CLUSTER_MINIMUM: int = 18
const ASTEROID_RING_CLUSTER_MAXIMUM: int = 24
const ASTEROID_RING_ROCKS_PER_CLUSTER_MINIMUM: int = 5
const ASTEROID_RING_ROCKS_PER_CLUSTER_MAXIMUM: int = 8
const FALLBACK_ENEMY_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemies/enemy_corsair.tscn"),
	preload("res://scenes/enemies/enemy_cutter.tscn"),
]

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
## Physical planet collider; its visual is selected by the map node's PlanetDefinition.
@export var planet_scene: PackedScene
## Number of hostile arrival waves before a non-station sector can clear.
@export_range(1, 8, 1) var waves_per_sector: int = 3

@onready var enemy_wave_timer: Timer = $EnemyWaveTimer

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var reserved_positions: Array[Vector2] = []
var asteroid_placements: Array[Dictionary] = []
var waves_remaining: int = 0
var enemy_budget_remaining: int = 0


func _ready() -> void:
	enemy_wave_timer.timeout.connect(_spawn_next_enemy_wave)
	var sector: SectorRoot = get_parent() as SectorRoot
	if sector != null and not sector.skip_hostile_spawns and sector.sector_id != "station":
		# Split a fixed sector budget into delayed arrivals; role-specific content cannot add extras.
		var total_enemy_budget: int = _scaled_enemy_total()
		var reinforcement_count: int = 0
		if (
			sector.has_outpost_objective
			and not RunState.outpost_destroyed
			and sector.reinforcement_enemy_scene != null
		):
			reinforcement_count = clampi(RunState.outpost_reinforcement_level, 0, 3)
		enemy_budget_remaining = maxi(0, total_enemy_budget - reinforcement_count)
		waves_remaining = mini(waves_per_sector, enemy_budget_remaining)
	call_deferred("_start_enemy_waves")


func _scaled_enemy_total() -> int:
	# Integer populations approximate a compounded +1% per committed sector.
	return maxi(3, roundi(3.0 * pow(1.01, float(maxi(RunState.world_tick, 0)))))


func _start_enemy_waves() -> void:
	if waves_remaining > 0:
		_spawn_next_enemy_wave()


func _spawn_next_enemy_wave() -> void:
	var sector: SectorRoot = get_parent() as SectorRoot
	if sector == null or waves_remaining <= 0 or sector.skip_hostile_spawns:
		return
	if sector.sector_id == "station":
		waves_remaining = 0
		return

	# Wave composition stays hidden, but every arrival consumes this sector's exact budget.
	var enemies_in_wave: int = ceili(float(enemy_budget_remaining) / float(waves_remaining))
	var spawn_position: Vector2 = _random_enemy_spawn_position(sector)
	if enemies_in_wave == 1:
		_spawn_individual_enemy(sector, spawn_position)
	else:
		_spawn_patrol_wave(sector, spawn_position, enemies_in_wave)
	enemy_budget_remaining -= enemies_in_wave
	waves_remaining -= 1
	if waves_remaining > 0:
		enemy_wave_timer.start()
	sector.call_deferred("_connect_enemy_death_signals")
	sector.call_deferred("_refresh_clear_state")


func _enemy_scene_choices() -> Array[PackedScene]:
	var system: SolarSystemDefinition = RunState.get_current_system()
	return system.enemy_scenes if system != null and not system.enemy_scenes.is_empty() else FALLBACK_ENEMY_SCENES


func _instantiate_wave_enemy() -> EnemyShip:
	var choices: Array[PackedScene] = _enemy_scene_choices()
	var enemy_scene: PackedScene = choices[rng.randi_range(0, choices.size() - 1)]
	var enemy: EnemyShip = enemy_scene.instantiate() as EnemyShip
	if enemy == null:
		Log.error("Wave enemy scene root must use EnemyShip.gd", enemy_scene.resource_path)
	return enemy


func _spawn_individual_enemy(sector: SectorRoot, at: Vector2) -> void:
	var enemy: EnemyShip = _instantiate_wave_enemy()
	if enemy == null:
		return
	# Use the live ship transform and stay outside camera view, minimap, and sensor contact.
	enemy.global_position = at
	sector.get_node("Encounters").add_child(enemy)


func _spawn_patrol_wave(sector: SectorRoot, at: Vector2, ship_count: int) -> void:
	# A wave can use a shared-alert patrol while the per-sector budget remains exact.
	var group := PatrolGroup.new()
	group.name = "GeneratedPatrolWave"
	group.position = at
	group.drifting = true
	group.drift_thrust = 0.2
	for index in range(ship_count):
		var enemy: EnemyShip = _instantiate_wave_enemy()
		if enemy == null:
			continue
		var angle: float = TAU * float(index) / float(ship_count)
		enemy.position = Vector2.RIGHT.rotated(angle) * rng.randf_range(90.0, 170.0)
		group.add_child(enemy)
	sector.get_node("Encounters").add_child(group)


## Populate the supplied generated sector deterministically from its role, seed, and system attributes.
func generate_sector(sector: SectorRoot) -> void:
	# The node seed makes this layout stable when the player leaves and returns.
	rng.seed = sector.sector_seed
	reserved_positions.clear()
	asteroid_placements.clear()
	if RunState.get_actual_caravan_sector() == sector.sector_id:
		# Leave a clear arrival pocket for the persistent caravan instance.
		reserved_positions.append(sector.spawn_position + sector.caravan_spawn_offset)
	_generate_asteroids(sector)
	_spawn_planet(sector)
	var optional_nebula_chance: float = clampf(float(_system_attribute(sector, &"nebula_chance", 0.2)), 0.0, 1.0)
	if sector.sector_id != "nebula" and rng.randf() < optional_nebula_chance:
		_spawn_scene(
			nebula_scene,
			sector.get_node("Landmarks"),
			_random_open_position(sector, 2400.0, _screen_world_radius(sector) + 2400.0),
		)

	# Each role guarantees its mission-critical actors; all positions remain seeded.
	match sector.sector_id:
		"asteroid_ring", "start", "patrol":
			pass # Hostiles for every role come only from the capped wave budget.
		"station":
			_spawn_sensor_area(
				station_scene,
				sector.get_node("Landmarks"),
				_random_open_position(sector, 800.0, 950.0),
			)
		"nebula":
			_spawn_nebula_objective(sector)
		"warp":
			if warp_gate_scene != null:
				_spawn_scene(
					warp_gate_scene,
					sector.get_node("Landmarks"),
					_random_open_position(sector, 600.0, 3000.0),
				)
		_:
			pass

	if sector.has_outpost_objective and not RunState.outpost_destroyed:
		_spawn_outpost(sector, _random_open_position(sector, 900.0, 1050.0))


func _generate_asteroids(sector: SectorRoot) -> void:
	# Clusters create visual grouping; conservative circle bounds keep every collider separate.
	var cluster_minimum: int = maxi(0, int(_system_attribute(sector, &"asteroid_cluster_minimum", 4)))
	var cluster_maximum: int = maxi(cluster_minimum, int(_system_attribute(sector, &"asteroid_cluster_maximum", 9)))
	var cluster_count: int = rng.randi_range(cluster_minimum, cluster_maximum)
	if sector.sector_id == "asteroid_ring":
		cluster_count = rng.randi_range(
			ASTEROID_RING_CLUSTER_MINIMUM,
			ASTEROID_RING_CLUSTER_MAXIMUM,
		)
	if sector.sector_id == "start":
		cluster_count = rng.randi_range(2, 4)
	for cluster_index in range(cluster_count):
		var cluster_position: Vector2 = _random_open_position(
			sector, 1100.0, _screen_world_radius(sector) + 1200.0,
		)
		reserved_positions.append(cluster_position)
		var rocks_in_cluster: int = (
			rng.randi_range(
				ASTEROID_RING_ROCKS_PER_CLUSTER_MINIMUM,
				ASTEROID_RING_ROCKS_PER_CLUSTER_MAXIMUM,
			)
			if sector.sector_id == "asteroid_ring"
			else rng.randi_range(2, 5)
		)
		for rock_index in range(rocks_in_cluster):
			var rock_radius: float = rng.randf_range(90.0, 150.0)
			var rock_position: Vector2 = _find_asteroid_position(sector, cluster_position, rock_radius)
			if rock_position.x < 0.0:
				continue

			var rock: RigidBody2D = ASTEROID_SCRIPT.new() as RigidBody2D
			if rock == null:
				Log.error("Could not instantiate asteroid physics body")
				return
			var visual: Polygon2D = Polygon2D.new()
			var collision: CollisionShape2D = CollisionShape2D.new()
			var collision_circle: CircleShape2D = CircleShape2D.new()
			var points: PackedVector2Array = _make_rock_polygon(rock_radius)
			visual.polygon = points
			visual.color = Color(
				rng.randf_range(0.16, 0.3),
				rng.randf_range(0.18, 0.32),
				rng.randf_range(0.26, 0.42),
				1.0,
			)
			# A circle keeps the moving rigid body on a supported convex collider and
			# matches the conservative radius used by the placement-overlap test.
			collision_circle.radius = rock_radius
			collision.shape = collision_circle
			rock.add_child(visual)
			rock.add_child(collision)
			rock.collision_layer = 1
			rock.collision_mask = 6
			rock.mass = rng.randf_range(7.0, 12.0)
			rock.linear_damp = 2.2
			rock.angular_damp = 2.5
			rock.add_to_group("sensor_contact")
			rock.add_to_group("asteroid")
			rock.set_meta("contact_type", "asteroid")
			rock.set_meta("sensor_signature", 0.65)
			rock.position = rock_position
			rock.rotation = rng.randf_range(0.0, TAU)
			sector.get_node("Asteroids").add_child(rock)
			asteroid_placements.append({"position": rock_position, "radius": rock_radius})
			reserved_positions.append(rock_position)


func _find_asteroid_position(sector: SectorRoot, cluster_center: Vector2, radius: float) -> Vector2:
	# Try broad cluster offsets; failed placements are skipped rather than overlapping a collider.
	for attempt in range(128):
		var offset: Vector2 = Vector2.ZERO
		if attempt > 0:
			offset = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(300.0, 650.0)
		var candidate: Vector2 = cluster_center + offset
		candidate.x = clampf(candidate.x, radius + 24.0, sector.sector_size.x - radius - 24.0)
		candidate.y = clampf(candidate.y, radius + 24.0, sector.sector_size.y - radius - 24.0)
		var player_position: Vector2 = _player_position(sector)
		var spawn_clearance: float = maxf(_screen_world_radius(sector), MINIMAP_SPAWN_CLEARANCE)
		if SectorSpace.wrapped_distance(candidate, player_position) < spawn_clearance + radius + 80.0:
			continue

		var overlaps_existing: bool = false
		for placement: Dictionary in asteroid_placements:
			var other_position: Vector2 = placement["position"]
			var other_radius: float = float(placement["radius"])
			if SectorSpace.wrapped_distance(candidate, other_position) < radius + other_radius + ASTEROID_CLEARANCE:
				overlaps_existing = true
				break
		if not overlaps_existing:
			return candidate
	return Vector2(-1.0, -1.0)


func _make_rock_polygon(base_radius: float) -> PackedVector2Array:
	# Radially varied vertices give each collidable asteroid a distinct silhouette.
	var points: PackedVector2Array = PackedVector2Array()
	var vertex_count: int = rng.randi_range(7, 11)
	for index in range(vertex_count):
		var angle: float = TAU * float(index) / float(vertex_count)
		var radius: float = rng.randf_range(base_radius * 0.72, base_radius)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _spawn_nebula_objective(sector: SectorRoot) -> void:
	# Keep the beacon near the nebula while avoiding a direct overlap with its center.
	var nebula_position: Vector2 = _random_open_position(
		sector, 2500.0, _screen_world_radius(sector) + 2400.0,
	)
	_spawn_scene(nebula_scene, sector.get_node("Landmarks"), nebula_position)
	var beacon_position: Vector2 = nebula_position + Vector2(950.0, 250.0)
	beacon_position.x = clampf(beacon_position.x, 250.0, sector.sector_size.x - 250.0)
	beacon_position.y = clampf(beacon_position.y, 250.0, sector.sector_size.y - 250.0)
	_spawn_sensor_area(intel_beacon_scene, sector.get_node("Landmarks"), beacon_position)


func _system_attribute(sector: SectorRoot, key: StringName, fallback: Variant) -> Variant:
	# Until solar-system generation exists, empty attributes use neutral prototype values.
	return sector.solar_system_attributes.get(key, fallback)


## Add the map-selected physical body without rolling a second, divergent identity.
func _spawn_planet(sector: SectorRoot) -> void:
	if sector.planet_id == &"":
		return
	if planet_scene == null:
		Log.error("A mapped planet has no PlanetBody scene configured", sector.map_node_id)
		return
	var planet_definition: PlanetDefinition = RunState.get_planet(sector.planet_id)
	if planet_definition == null:
		Log.error("Map references an unknown planet YARD ID", sector.planet_id)
		return
	var planet: PlanetBody = planet_scene.instantiate() as PlanetBody
	if planet == null:
		Log.error("Planet scene root must use PlanetBody.gd", planet_scene.resource_path)
		return
	planet.configure(planet_definition)
	planet.position = _random_open_position(sector, planet_definition.radius + 300.0, 1600.0)
	sector.get_node("Landmarks").add_child(planet)
	reserved_positions.append(planet.position)


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


func _random_enemy_spawn_position(sector: SectorRoot) -> Vector2:
	# Include the patrol's widest child offset so every ship starts beyond sensor range.
	var player: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
	var center: Vector2 = player.global_position if is_instance_valid(player) else sector.spawn_position
	var minimum_distance: float = enemy_spawn_distance(sector)
	for attempt in range(64):
		var candidate: Vector2 = (
			center
			+ Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
			* (minimum_distance + rng.randf_range(20.0, 220.0))
		)
		candidate = SectorSpace.wrap_position(candidate)
		var blocked: bool = false
		for reserved in reserved_positions:
			if SectorSpace.wrapped_distance(candidate, reserved) < 350.0:
				blocked = true
				break
		if not blocked:
			return candidate
	for index in range(16):
		var fallback: Vector2 = SectorSpace.wrap_position(
			center + Vector2.RIGHT.rotated(TAU * float(index) / 16.0) * (minimum_distance + 120.0),
		)
		var fallback_blocked: bool = false
		for reserved in reserved_positions:
			if SectorSpace.wrapped_distance(fallback, reserved) < 350.0:
				fallback_blocked = true
				break
		if not fallback_blocked:
			return fallback
	return SectorSpace.wrap_position(center + Vector2.LEFT * (minimum_distance + 120.0))


## Return the spawn radius that keeps every hostile beyond view, radar, and minimap range.
func enemy_spawn_distance(sector: SectorRoot) -> float:
	var player: PlayerShip = get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var sensor_range: float = 0.0
	if is_instance_valid(player):
		var sensor: SensorComponent = player.get_node_or_null("SensorComponent") as SensorComponent
		if sensor != null:
			sensor_range = player.sensor_range
	# The marker range is a second hard floor so a newly arrived enemy is absent from the map.
	return maxf(
		sensor_range + 400.0,
		maxf(_screen_world_radius(sector) + 100.0, MINIMAP_SPAWN_CLEARANCE + 100.0),
	)


func _player_position(sector: SectorRoot) -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player_ship") as Node2D
	return player.global_position if is_instance_valid(player) else sector.spawn_position


func _screen_world_radius(sector: SectorRoot) -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		viewport_size /= camera.zoom.abs().max(Vector2(0.01, 0.01))
	# Wrap-aware sectors may be smaller than the viewport; clamp to their usable half-size.
	return minf(viewport_size.length() * 0.5, minf(sector.sector_size.x, sector.sector_size.y) * 0.5)


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
		var player_position: Vector2 = _player_position(sector)
		var required_distance: float = maxf(
			minimum_spawn_distance,
			maxf(MINIMAP_SPAWN_CLEARANCE, _screen_world_radius(sector)),
		)
		if SectorSpace.wrapped_distance(candidate, player_position) < required_distance:
			continue
		var blocked: bool = false
		for reserved in reserved_positions:
			if SectorSpace.wrapped_distance(candidate, reserved) < clearance:
				blocked = true
				break
		if not blocked:
			return candidate
	# Failed random placement must not hide required content on the far edge of the sector.
	var fallback_required_distance: float = maxf(
		minimum_spawn_distance,
		maxf(MINIMAP_SPAWN_CLEARANCE, _screen_world_radius(sector)),
	)
	var fallback_radius: float = fallback_required_distance + 150.0
	var fallback_player_position: Vector2 = _player_position(sector)
	for index in range(16):
		var angle: float = TAU * float(index) / 16.0
		var fallback: Vector2 = SectorSpace.wrap_position(
			fallback_player_position + Vector2.RIGHT.rotated(angle) * fallback_radius,
		)
		if SectorSpace.wrapped_distance(fallback, fallback_player_position) < fallback_required_distance:
			continue
		var blocked: bool = false
		for reserved in reserved_positions:
			if SectorSpace.wrapped_distance(fallback, reserved) < clearance:
				blocked = true
				break
		if not blocked:
			return fallback
	Log.error("Could not find a clear off-map spawn position", sector.map_node_id)
	return SectorSpace.wrap_position(fallback_player_position + Vector2(fallback_radius, 0.0))
