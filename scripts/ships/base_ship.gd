extends CharacterBody2D
# BaseShip owns shared movement, combat, shields, and module application.
class_name BaseShip

signal died(ship: BaseShip)
signal hull_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal modules_changed

const SHIPS: Registry = preload("res://assets/data/registries/ships.tres")

# YARD supplies the authored ship ID; the editor hint offers registry-backed selection.
@export_custom(Registry.PROPERTY_HINT_CUSTOM, "res://assets/data/registries/ships.tres") var ship_id: StringName = &"prototype_ship"

# Team 0 is the player; every nonzero team is treated as hostile in this prototype.
@export var team: int = 0
# Assign a projectile scene implementing velocity, damage, team, and source properties.
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
var installed_modules: Array[ModuleDefinition] = []

# NEW CODE STARTS HERE
# Preserve a smooth world-space coordinate for camera-driven background shaders.
var unwrapped_world_position: Vector2 = Vector2.ZERO
var _previous_wrapped_position: Vector2 = Vector2.ZERO
# NEW CODE ENDS HERE


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

	# NEW CODE STARTS HERE
	# Normalize the spawn and seed the continuous coordinate before movement begins.
	unwrapped_world_position = global_position
	_previous_wrapped_position = SectorSpace.wrap_position(global_position)
	global_position = _previous_wrapped_position
	# NEW CODE ENDS HERE

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	add_to_group("ships")
	add_to_group("sensor_contact")

	# NEW CODE STARTS HERE
	# Display neighboring copies near sector edges without duplicating ship physics.
	var wrap_visual := get_node_or_null("Visuals") as Node2D
	if wrap_visual != null:
		SectorSpace.register_wrap_visual(self, wrap_visual)
	# NEW CODE ENDS HERE

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

	# NEW CODE STARTS HERE
	# Accumulate actual movement before canonicalizing the toroidal sector position.
	var raw_position: Vector2 = global_position
	unwrapped_world_position += SectorSpace.shortest_delta(_previous_wrapped_position, raw_position)
	var wrapped_position: Vector2 = SectorSpace.wrap_position(raw_position)
	if raw_position.distance_squared_to(wrapped_position) > 0.0001:
		global_position = wrapped_position
		# Avoid rendering interpolation across the large coordinate discontinuity.
		reset_physics_interpolation()
	_previous_wrapped_position = wrapped_position
	# NEW CODE ENDS HERE


# NEW CODE STARTS HERE
func _exit_tree() -> void:
	# Keep runtime render copies from outliving this ship.
	SectorSpace.unregister_wrap_visual(self)
# NEW CODE ENDS HERE


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
	# Apply thrust, drag, and the authored speed cap in that order.
	var forward := Vector2.RIGHT.rotated(rotation)

	if command_thrust > 0.0:
		velocity += forward * thrust_acceleration * command_thrust * delta

	velocity = velocity.move_toward(Vector2.ZERO, linear_drag * delta)

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed


func _update_shield(delta: float) -> void:
	# Regeneration is blocked briefly after damage and never exceeds max_shield.
	if shield_regen_block_time > 0.0:
		return

	if shield >= max_shield:
		return

	shield = min(shield + shield_regen_per_second * delta, max_shield)

	shield_changed.emit(shield, max_shield)
	_update_shield_visual()


func try_fire() -> void:
	# Projectiles inherit the ship's current direction, damage, and team.
	if projectile_scene == null or muzzle == null:
		return

	if weapon_cooldown_left > 0.0:
		return

	weapon_cooldown_left = weapon_cooldown

	var projectile = projectile_scene.instantiate()
	projectile.global_position = muzzle.global_position
	projectile.rotation = rotation
	projectile.velocity = (Vector2.RIGHT.rotated(rotation) * projectile_speed)
	projectile.damage = projectile_damage
	projectile.team = team
	projectile.source = self

	get_tree().current_scene.add_child(projectile)


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


func restore_shield(amount: float) -> void:
	# Ignore invalid healing values so this API cannot accidentally cause damage.
	if is_dead or amount <= 0.0:
		return

	shield = min(shield + amount, max_shield)
	shield_changed.emit(shield, max_shield)
	_update_shield_visual()


func repair_hull(amount: float) -> void:
	# Repairs are positive-only and do not revive a ship after its death event.
	if is_dead or amount <= 0.0:
		return

	hull = min(hull + amount, max_hull)
	hull_changed.emit(hull, max_hull)


func install_module(module: ModuleDefinition) -> bool:
	# Slot capacity is enforced here so pickups and shops share one rule.
	if module == null or installed_modules.size() >= module_slots:
		return false

	installed_modules.append(module)
	_rebuild_stats(false)
	modules_changed.emit()
	Log.info("Module installed", module.display_name, installed_modules.size(), module_slots)
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
