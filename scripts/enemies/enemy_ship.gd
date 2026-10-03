extends BaseShip
## Sensor-driven hostile ship with patrol alert sharing and a bounded search state.
class_name EnemyShip

const MODULE_DROP_CHANCE: float = 0.35
const WEAPON_DROP_CHANCE: float = 0.24

## Awareness state; SEARCH follows the last confirmed location without firing.
enum State {
	UNAWARE,
	AGGRO,
	SEARCH,
}


## Available attack patterns while the player is an active sensor contact.
enum AIStyle {
	STRAFE,
	CHARGE,
	INTERCEPTOR,
	SNIPER,
}

## Aggressive enemies keep engaging instead of retreating when their shields are low.
enum EnemySubtype {
	STANDARD,
	AGGRESSIVE,
}

## Tactic used while pursuing a currently detected player.
@export var ai_style: AIStyle = AIStyle.STRAFE
## STANDARD enemies flee at low shields; AGGRESSIVE enemies do not.
@export var enemy_subtype: EnemySubtype = EnemySubtype.STANDARD
## Legacy pursuit radius, applied in addition to a live sensor contact.
@export_range(0.0, 4000.0, 25.0) var aggro_range: float = 1250.0

## Seconds to search the last confirmed position after sensor contact is lost.
@export_range(0.0, 10.0, 0.5) var search_duration: float = 4.0
var last_known_player_position: Vector2 = Vector2.ZERO
var search_time_left: float = 0.0
@onready var sensor_component: SensorComponent = $SensorComponent

## Range at which this ship is allowed to fire at a live contact.
@export_range(0.0, 4000.0, 25.0) var attack_range: float = 900.0
## Break contact and retreat below this fraction of the ship's shield capacity.
@export_range(0.05, 0.75, 0.05) var flee_shield_ratio: float = 0.25
## Preferred separation used by the STRAFE tactic.
@export_range(0.0, 2500.0, 25.0) var desired_distance: float = 650.0
## Range band favored by Interceptors and Snipers.
@export_range(100.0, 2500.0, 25.0) var preferred_range: float = 1100.0
## Lateral acceleration used by the STRAFE tactic.
@export_range(0.0, 1000.0, 25.0) var strafe_acceleration: float = 220.0
## Thrust command while unaware; patrol groups may override this value.
@export_range(0.0, 1.0, 0.05) var unaware_thrust: float = 0.0
## Heading maintained while unaware, before patrol-group overrides.
@export var unaware_heading: Vector2 = Vector2.RIGHT

## Optional death effect and pickups assigned by the enemy scene.
@export var explosion_scene: PackedScene
## Optional shield pickup spawned on death.
@export var shield_booster_scene: PackedScene
## Rare high-value shield pickup dropped independently from the common canister.
@export var large_shield_booster_scene: PackedScene
## Optional module pickup spawned on death.
@export var module_pickup_scene: PackedScene
## Weapon pickup instantiated when this enemy's weapon-drop roll succeeds.
@export var weapon_pickup_scene: PackedScene

# Cache the player after it joins BaseShip's player_ship group.
var state: State = State.UNAWARE
var player: Node2D = null


func _ready() -> void:
	# Set the hostile team before BaseShip registers this ship in groups.
	team = 1
	super._ready()
	if definition != null:
		_apply_sector_difficulty()


func _apply_sector_difficulty() -> void:
	# Keep the long-term ramp, then apply the requested global 10% enemy nerf.
	var multiplier: float = RunState.enemy_difficulty_multiplier() * 0.9
	max_hull *= multiplier
	hull *= multiplier
	max_shield *= multiplier
	shield *= multiplier
	shield_regen_per_second *= multiplier
	projectile_damage *= multiplier
	projectile_speed *= multiplier
	max_speed *= multiplier
	thrust_acceleration *= multiplier
	turn_speed *= multiplier
	weapon_cooldown /= multiplier
	hull_changed.emit(hull, max_hull)
	shield_changed.emit(shield, max_shield)


func _gather_commands(delta: float) -> void:
	# Resolve the player lazily so scene entry order does not matter.
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player_ship") as Node2D

	if not is_instance_valid(player):
		command_thrust = 0.0
		command_fire = false
		if state == State.AGGRO:
			state = State.SEARCH
			search_time_left = search_duration
		elif state == State.SEARCH:
			search_time_left -= delta
			if search_time_left <= 0.0:
				state = State.UNAWARE
		return

	
	# Keep the Step 8 aggro radius, but require the sensor refreshed contact list.
	var player_distance: float = SectorSpace.wrapped_distance(global_position, player.global_position)
	var has_player_contact: bool = (
		player_distance <= aggro_range and sensor_component.has_contact(player)
	)
	if has_player_contact:
		# Only confirmed contacts can update the position being searched.
		last_known_player_position = player.global_position
		if state != State.AGGRO:
			become_aggro()
	elif state == State.AGGRO:
		state = State.SEARCH
		search_time_left = search_duration

	var target_position: Vector2 = player.global_position
	if state == State.SEARCH:
		target_position = last_known_player_position

	var to_player: Vector2 = SectorSpace.shortest_delta(global_position, target_position)
	var distance: float = to_player.length()

	if state == State.UNAWARE:
		command_heading = unaware_heading.normalized()
		command_thrust = unaware_thrust
		command_fire = false
		return

	if state == State.SEARCH:
		search_time_left -= delta
		if search_time_left <= 0.0:
			state = State.UNAWARE
			command_thrust = 0.0
			command_fire = false
			return

		# Search the last confirmed position, but never fire without live contact.
		command_heading = to_player.normalized()
		command_thrust = 0.35 if distance > 100.0 else 0.0
		command_fire = false
		return

	if _should_flee():
		# Fleeing is intentionally slower so a player can close the gap and finish the chase.
		command_heading = -to_player.normalized()
		command_thrust = 0.45
		command_fire = false
		return

	# AGGRO keeps the Step 8 aim, strafe/charge, and firing behavior.
	var target_direction: Vector2 = to_player.normalized()
	command_heading = target_direction

	match ai_style:
		AIStyle.STRAFE:
			if distance > desired_distance + 100.0:
				command_thrust = 0.65
			elif distance < desired_distance - 100.0:
				command_thrust = 0.0
				velocity -= target_direction * thrust_acceleration * 0.55 * delta
			else:
				command_thrust = 0.0
				var tangent: Vector2 = target_direction.rotated(PI / 2.0)
				velocity += tangent * strafe_acceleration * delta

		AIStyle.CHARGE:
			command_thrust = 1.0 if distance > 260.0 else 0.15

	var aim_error: float = absf(angle_difference(rotation, target_direction.angle()))
	command_fire = distance <= attack_range and aim_error <= deg_to_rad(14.0)
	if ai_style == AIStyle.INTERCEPTOR:
		command_thrust = 1.0 if distance > preferred_range else 0.35
	elif ai_style == AIStyle.SNIPER:
		command_thrust = 0.8 if distance > preferred_range else 0.0
		if distance < preferred_range * 0.65:
			command_thrust = 1.0


## Cap retreat velocity separately so accumulated momentum cannot keep a fleeing enemy fast.
func _movement_speed_limit() -> float:
	if _should_flee():
		return max_speed * 0.55
	return super._movement_speed_limit()


func _should_flee() -> bool:
	return (
		enemy_subtype != EnemySubtype.AGGRESSIVE
		and max_shield > 0.0
		and shield <= max_shield * flee_shield_ratio
	)

## Enter active pursuit after this ship's sensor confirms the player.
func become_aggro() -> void:
	# Run alert side effects once, even if more than one detection occurs.
	if state == State.AGGRO:
		return

	state = State.AGGRO
	Log.info("Enemy entered aggro", name, RunState.current_sector_id)

	var active_sector: SectorRoot = get_tree().get_first_node_in_group("active_sector") as SectorRoot
	if active_sector != null and active_sector.has_outpost_objective:
		RunState.outpost_alerted = true

	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("alert_all"):
		parent_node.alert_all(self)


## Receive a patrol alert; a supplied position is knowledge only, not live sensor contact.
func force_aggro(known_player_position: Vector2 = Vector2.ZERO) -> void:
	# Patrol alerts share the source ships confirmed location without granting contact.
	last_known_player_position = known_player_position
	state = State.AGGRO
	search_time_left = search_duration


func _die() -> void:
	# Prevent duplicate bounties if death is requested more than once.
	if is_dead:
		return

	if explosion_scene != null:
		var effect := explosion_scene.instantiate() as Node2D
		if effect != null:
			# The ship definition selects one fixed explosion look for this enemy type.
			if definition != null and definition.explosion_visual != null:
				var explosion_sprite: Sprite2D = effect as Sprite2D
				if explosion_sprite != null:
					explosion_sprite.texture = definition.explosion_visual
			SectorSpace.spawn_owned(effect, global_position)
	if GameSettings.screen_shake_strength > 0.0:
		Juicee.shake_camera(self, 3.0 * GameSettings.screen_shake_strength, 0.22, 20.0)

	if shield_booster_scene != null and randf() < 0.12:
		SectorSpace.spawn_owned(shield_booster_scene.instantiate(), global_position)
	if large_shield_booster_scene != null and randf() < 0.025:
		SectorSpace.spawn_owned(large_shield_booster_scene.instantiate(), global_position)

	if module_pickup_scene != null and randf() < MODULE_DROP_CHANCE:
		var dropped_module: ModuleDefinition = RunState.get_random_module()
		if dropped_module != null:
			var pickup: Node = module_pickup_scene.instantiate()
			pickup.set("module", dropped_module)
			SectorSpace.spawn_owned(pickup, global_position)
			Log.info("Enemy dropped a module", name, dropped_module.display_name)
	elif module_pickup_scene == null:
		Log.error("Enemy has no module pickup scene assigned", name)
	if weapon_pickup_scene != null and randf() < WEAPON_DROP_CHANCE:
		var dropped_weapon: WeaponDefinition = RunState.get_random_weapon()
		if dropped_weapon != null:
			var pickup: WeaponPickup = weapon_pickup_scene.instantiate() as WeaponPickup
			if pickup != null:
				pickup.weapon = dropped_weapon
				SectorSpace.spawn_owned(pickup, global_position)
				Log.info("Enemy dropped a weapon", name, dropped_weapon.display_name)

	RunState.add_credits(randi_range(4, 9))
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("enemy_death", self, "SFX")
	Log.info("Enemy defeated", name, global_position)
	super._die()
