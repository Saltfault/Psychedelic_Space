extends CharacterBody2D
## Shared ship physics, combat, defensive stats, sensors, and module application.
class_name BaseShip

## Emitted once when hull reaches zero; listeners may spawn effects or persist consequences.
signal died(ship: BaseShip)
## Emitted whenever current hull changes, with the current maximum as the second argument.
signal hull_changed(current: float, maximum: float)
## Emitted whenever current shields change, with the current maximum as the second argument.
signal shield_changed(current: float, maximum: float)
## Emitted whenever equipped or unequipped module inventories change.
signal modules_changed

const SHIPS: Registry = preload("res://assets/data/registries/ships.tres")

## Stable YARD ID of the ShipDefinition that provides this ship's baseline statistics.
@export_custom(
	Registry.PROPERTY_HINT_CUSTOM,
	"res://assets/data/registries/ships.tres",
) var ship_id: StringName = &"prototype_ship"

## Combat team used by projectiles to decide whether this ship is a valid target.
@export var team: int = 0
## Projectile scene with the Projectile script; required when this ship can fire.
@export var projectile_scene: PackedScene

@onready var muzzle: Marker2D = $Muzzle
@onready var shield_visual: Sprite2D = $Visuals/ShieldVisual

var definition: ShipDefinition = null

var command_heading: Vector2 = Vector2.RIGHT
var command_thrust: float = 0.0
var command_fire: bool = false

var max_speed: float
var thrust_acceleration: float
var linear_drag: float
var turn_speed: float

var max_hull: float
var hull: float
var is_dead: bool = false

var max_shield: float
var shield: float
var shield_regen_per_second: float
var shield_regen_delay: float
var shield_regen_block_time: float = 0.0

var weapon_cooldown: float
var projectile_speed: float
var projectile_damage: float
var weapon_cooldown_left: float = 0.0

var sensor_range: float
var module_slots: int
## Modules currently equipped and contributing to this ship's derived stats.
var installed_modules: Array[ModuleDefinition] = []
## Owned modules waiting in reserve; these do not affect ship stats until equipped.
var unequipped_modules: Array[ModuleDefinition] = []


# Preserve a smooth world-space coordinate for camera-driven background shaders.
var unwrapped_world_position: Vector2 = Vector2.ZERO
var _previous_wrapped_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Resolve authored stats once, then disable processing if the ID is invalid.
	definition = SHIPS.load_entry(ship_id) as ShipDefinition

	if definition == null:
		Log.error("YARD could not load ShipDefinition ID", ship_id)
		set_physics_process(false)
		return
	if muzzle == null:
		Log.error("BaseShip is missing its Muzzle Marker2D child", get_path())
		set_physics_process(false)
		return

	# Normalize the spawn and seed the continuous coordinate before movement begins.
	unwrapped_world_position = global_position
	_previous_wrapped_position = SectorSpace.wrap_position(global_position)
	global_position = _previous_wrapped_position

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	add_to_group("ships")
	add_to_group("sensor_contact")

	# Display neighboring copies near sector edges without duplicating ship physics.
	var wrap_visual := get_node_or_null("Visuals") as Node2D
	if wrap_visual != null:
		SectorSpace.register_wrap_visual(self, wrap_visual)

	if team == 0:
		add_to_group("player_ship")
	else:
		add_to_group("enemy_ship")

	_rebuild_stats(true)
	_update_shield_visual()
	Log.info("Ship definition loaded", ship_id, definition.display_name)


func _physics_process(delta: float) -> void:
	# Every frame follows the same order: input, timers, steering, shields, firing, motion.
	_gather_commands(delta)

	weapon_cooldown_left = max(weapon_cooldown_left - delta, 0.0)
	shield_regen_block_time = max(shield_regen_block_time - delta, 0.0)

	_update_rotation(delta)
	_update_movement(delta)
	_update_shield(delta)

	if command_fire:
		try_fire()

	move_and_slide()

	# Accumulate actual movement before canonicalizing the toroidal sector position.
	var raw_position: Vector2 = global_position
	unwrapped_world_position += SectorSpace.shortest_delta(_previous_wrapped_position, raw_position)
	var wrapped_position: Vector2 = SectorSpace.wrap_position(raw_position)
	if raw_position.distance_squared_to(wrapped_position) > 0.0001:
		global_position = wrapped_position
		# Avoid rendering interpolation across the large coordinate discontinuity.
		reset_physics_interpolation()
	_previous_wrapped_position = wrapped_position


func _exit_tree() -> void:
	# Keep runtime render copies from outliving this ship.
	SectorSpace.unregister_wrap_visual(self)


func _gather_commands(_delta: float) -> void:
	# Subclasses override this input hook; the base implementation is inert.
	command_heading = Vector2.RIGHT.rotated(rotation)
	command_thrust = 0.0
	command_fire = false


func _update_rotation(delta: float) -> void:
	# Rotate only when a meaningful heading has been requested.
	if command_heading.length_squared() < 0.001:
		return

	var target_angle := command_heading.angle()
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)


func _update_movement(delta: float) -> void:
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	if command_thrust > 0.0:
		velocity += forward * thrust_acceleration * command_thrust * delta
	velocity = velocity.move_toward(Vector2.ZERO, linear_drag * delta)

	# Use a virtual limit so a short player Dash is not erased by the normal hull cap.
	var speed_limit: float = _movement_speed_limit()
	if velocity.length() > speed_limit:
		velocity = velocity.normalized() * speed_limit


func _movement_speed_limit() -> float:
	return max_speed


func _update_shield(delta: float) -> void:
	# Regeneration is blocked briefly after damage and never exceeds max_shield.
	if shield_regen_block_time > 0.0:
		return

	if shield >= max_shield:
		return

	shield = min(shield + shield_regen_per_second * delta, max_shield)

	shield_changed.emit(shield, max_shield)
	_update_shield_visual()


## Spawn one projectile if the weapon is ready and its configured scene is valid.
func try_fire() -> void:
	# Projectiles inherit the ship's current direction, damage, and team.
	if projectile_scene == null or muzzle == null:
		return

	if weapon_cooldown_left > 0.0:
		return

	weapon_cooldown_left = weapon_cooldown

	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		Log.error("Projectile scene root must use Projectile.gd", projectile_scene.resource_path)
		return
	projectile.rotation = rotation
	projectile.velocity = (Vector2.RIGHT.rotated(rotation) * projectile_speed)
	projectile.damage = projectile_damage
	projectile.team = team
	projectile.source = self
	if definition != null:
		projectile.visual_override = definition.projectile_visual

	SectorSpace.spawn_owned(projectile, muzzle.global_position)


## Apply nonnegative damage to shields first, then hull; emits change and death signals.
func take_damage(amount: float) -> void:
	# Damage is absorbed by shields first; only overflow reaches hull.
	if is_dead or amount <= 0.0:
		return

	shield_regen_block_time = shield_regen_delay

	var remaining := amount

	if shield > 0.0:
		# minf returns a float explicitly, avoiding Variant inference under strict warnings.
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)

	if remaining > 0.0:
		hull = max(hull - remaining, 0.0)
		hull_changed.emit(hull, max_hull)

	_update_shield_visual()
	Log.debug("Ship took damage", amount, shield, hull)

	if hull <= 0.0:
		_die()


## Restore up to amount shield points without exceeding the current maximum.
func restore_shield(amount: float) -> void:
	# Ignore invalid healing values so this API cannot accidentally cause damage.
	if is_dead or amount <= 0.0:
		return

	shield = min(shield + amount, max_shield)
	shield_changed.emit(shield, max_shield)
	_update_shield_visual()


## Restore up to amount hull points without exceeding the current maximum.
func repair_hull(amount: float) -> void:
	# Repairs are positive-only and do not revive a ship after its death event.
	if is_dead or amount <= 0.0:
		return

	hull = min(hull + amount, max_hull)
	hull_changed.emit(hull, max_hull)


## Equip a module directly when a slot is available; returns false without changing state otherwise.
func install_module(module: ModuleDefinition) -> bool:
	# Validate slot capacity before changing equipment or rebuilding derived stats.
	if module == null or installed_modules.size() >= module_slots:
		return false

	installed_modules.append(module)
	_rebuild_stats(false)
	modules_changed.emit()
	Log.info("Module installed", module.display_name, installed_modules.size(), module_slots)
	return true


## Add an acquired module to reserve without changing the ship's current stats.
func store_module(module: ModuleDefinition) -> bool:
	if module == null:
		return false

	unequipped_modules.append(module)
	modules_changed.emit()
	Log.info("Module added to unequipped inventory", module.display_name, unequipped_modules.size())
	return true


## Move a reserve module into an available equipment slot and apply its stats.
func equip_module(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= unequipped_modules.size():
		return false
	if installed_modules.size() >= module_slots:
		return false

	var module: ModuleDefinition = unequipped_modules[inventory_index]
	unequipped_modules.remove_at(inventory_index)
	if not install_module(module):
		unequipped_modules.insert(inventory_index, module)
		return false

	Log.info("Module equipped from inventory", module.display_name)
	return true


## Move an equipped module to reserve and rebuild stats without that module.
func unequip_module(equipped_index: int) -> bool:
	if equipped_index < 0 or equipped_index >= installed_modules.size():
		return false

	var module: ModuleDefinition = installed_modules[equipped_index]
	installed_modules.remove_at(equipped_index)
	unequipped_modules.append(module)
	_rebuild_stats(false)
	modules_changed.emit()
	Log.info("Module moved to unequipped inventory", module.display_name)
	return true


func _rebuild_stats(initializing: bool) -> void:
	# Rebuild from the base Resource every time, then apply installed modules.
	if definition == null:
		Log.error("Ship has no loaded ShipDefinition", get_path())
		return

	max_speed = definition.max_speed
	thrust_acceleration = definition.thrust_acceleration
	linear_drag = definition.linear_drag
	turn_speed = deg_to_rad(definition.turn_speed_degrees)

	max_hull = definition.max_hull
	max_shield = definition.max_shield
	shield_regen_per_second = definition.shield_regen_per_second
	shield_regen_delay = definition.shield_regen_delay

	weapon_cooldown = definition.weapon_cooldown
	projectile_speed = definition.projectile_speed
	projectile_damage = definition.projectile_damage

	sensor_range = definition.sensor_range
	module_slots = definition.module_slots

	for module in installed_modules:
		match module.effect:
			ModuleDefinition.Effect.MAX_HULL_ADD:
				max_hull += module.value

			ModuleDefinition.Effect.MAX_SHIELD_ADD:
				max_shield += module.value

			ModuleDefinition.Effect.FIRE_COOLDOWN_MULTIPLY:
				weapon_cooldown *= module.value

			ModuleDefinition.Effect.PROJECTILE_DAMAGE_MULTIPLY:
				projectile_damage *= module.value

			ModuleDefinition.Effect.THRUST_MULTIPLY:
				thrust_acceleration *= module.value

			ModuleDefinition.Effect.SENSOR_RANGE_MULTIPLY:
				sensor_range *= module.value

	if initializing:
		hull = max_hull
		shield = max_shield
	else:
		hull = min(hull, max_hull)
		shield = min(shield, max_shield)

	hull_changed.emit(hull, max_hull)
	shield_changed.emit(shield, max_shield)


func _update_shield_visual() -> void:
	# Keep the visual optional so enemy scenes can omit the player shield graphic.
	if shield_visual == null:
		return

	var shield_material := shield_visual.material as ShaderMaterial

	if shield_material == null:
		# Do not display the shield sprite before its shader material is assigned.
		shield_visual.visible = false
		return

	var ratio := 0.0

	if max_shield > 0.0:
		ratio = shield / max_shield

	shield_material.set_shader_parameter("strength", ratio)
	shield_visual.visible = ratio > 0.01


func _die() -> void:
	# Multiple hits in one frame must still produce only one death event.
	if is_dead:
		return

	is_dead = true
	Log.info("Ship destroyed", name, team)
	died.emit(self)
	queue_free()
