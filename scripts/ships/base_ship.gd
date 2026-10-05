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
## Emitted when the ship's active primary weapon changes.
signal weapon_changed(weapon: WeaponDefinition)

const UNEQUIPPED_MODULE_CAPACITY: int = 25
## All hulls and pilots start with this independent weapon; pickups replace it during a run.
const STARTING_WEAPON_ID: StringName = &"pulse_cannon"
const FALLBACK_WEAPON_COOLDOWN: float = 0.18
const FALLBACK_PROJECTILE_SPEED: float = 1000.0
const FALLBACK_PROJECTILE_DAMAGE: float = 10.0

## Stable YARD ID of the ShipDefinition that provides this ship's baseline statistics.
@export var ship_id: StringName = &"prototype_ship"

## Combat team used by projectiles to decide whether this ship is a valid target.
@export var team: int = 0
## Developer invulnerability consumed by the shared damage pipeline for the player team.
var god_mode: bool = false
## Projectile scene with the Projectile script; required when this ship can fire.
@export var projectile_scene: PackedScene

@onready var muzzle: Marker2D = $Muzzle
@onready var shield_visual: Sprite2D = $Visuals/ShieldVisual
@onready var hull_visual: Sprite2D = get_node_or_null("Visuals/Hull") as Sprite2D
@onready var engine_audio: AudioStreamPlayer2D = get_node_or_null("EngineAudio") as AudioStreamPlayer2D

var definition: ShipDefinition = null
## Current data-backed primary weapon; legacy ShipDefinition stats are fallback-only.
var weapon_definition: WeaponDefinition
var active_weapon_id: StringName = &""

var command_heading: Vector2 = Vector2.RIGHT
var command_thrust: float = 0.0
var command_fire: bool = false
## Optional controller-requested speed cap; negative keeps the authored ship maximum.
var command_speed_limit: float = -1.0

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
	definition = RunState.get_ship(ship_id)

	if definition == null:
		Log.error("YARD could not load ShipDefinition ID", ship_id)
		set_physics_process(false)
		return
	if engine_audio != null:
		engine_audio.stream = definition.engine_loop
		engine_audio.pitch_scale = definition.engine_pitch_scale
		if engine_audio.stream is AudioStreamWAV:
			(engine_audio.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if muzzle == null:
		Log.error("BaseShip is missing its Muzzle Marker2D child", get_path())
		set_physics_process(false)
		return
	if hull_visual != null and definition.hull_texture != null:
		hull_visual.texture = definition.hull_texture
		hull_visual.region_enabled = true
		hull_visual.region_rect = definition.hull_region
		if team == 0:
			hull_visual.texture = RunState.get_ship_color_texture(GameSettings.selected_ship_color_id)

	# Weapon selection belongs to run combat/pickups, never to the selected hull or pilot.
	weapon_definition = RunState.get_weapon(STARTING_WEAPON_ID)
	if weapon_definition == null:
		Log.error("The universal starting weapon is missing from YARD", STARTING_WEAPON_ID)
	else:
		active_weapon_id = weapon_definition.weapon_id
		projectile_scene = weapon_definition.projectile_scene

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
		set_meta("contact_type", "player")
	else:
		add_to_group("enemy_ship")
		set_meta("contact_type", "enemy")

	_rebuild_stats(true)
	if weapon_definition != null:
		weapon_changed.emit(weapon_definition)
	_update_shield_visual()
	Log.info("Ship definition loaded", ship_id, definition.display_name)


func _physics_process(delta: float) -> void:
	# Every frame follows the same order: input, timers, steering, shields, firing, motion.
	_gather_commands(delta)
	_update_engine_audio()

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
	var outside_sector_bounds: bool = (
		raw_position.x < 0.0
		or raw_position.x >= SectorSpace.sector_size.x
		or raw_position.y < 0.0
		or raw_position.y >= SectorSpace.sector_size.y
	)
	if outside_sector_bounds:
		global_position = wrapped_position
		# Avoid rendering interpolation across the large coordinate discontinuity.
		reset_physics_interpolation()
	_previous_wrapped_position = wrapped_position


func _update_engine_audio() -> void:
	# Keep the continuous loop tied to thrust; dash activation remains a separate one-shot.
	if engine_audio == null or engine_audio.stream == null:
		return
	var should_play: bool = not is_dead and command_thrust > 0.03
	if should_play and not engine_audio.playing:
		engine_audio.play()
	elif not should_play and engine_audio.playing:
		engine_audio.stop()


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
	else:
		velocity = velocity.move_toward(Vector2.ZERO, linear_drag * delta)

	# Use a virtual limit so a short player Dash is not erased by the normal hull cap.
	var speed_limit: float = _movement_speed_limit()
	if velocity.length() > speed_limit:
		velocity = velocity.normalized() * speed_limit


func _movement_speed_limit() -> float:
	return command_speed_limit if command_speed_limit >= 0.0 else max_speed


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
	# YARD definitions own the projectile scene and volley pattern.
	var firing_scene: PackedScene = weapon_definition.projectile_scene if weapon_definition != null else projectile_scene
	if firing_scene == null or muzzle == null:
		return

	if weapon_cooldown_left > 0.0:
		return

	weapon_cooldown_left = weapon_cooldown

	var shot_count: int = weapon_definition.projectile_count if weapon_definition != null else 1
	var spread: float = deg_to_rad(weapon_definition.spread_degrees) if weapon_definition != null else 0.0
	for shot_index in range(shot_count):
		var spread_offset: float = 0.0
		if shot_count > 1:
			spread_offset = lerpf(-spread * 0.5, spread * 0.5, float(shot_index) / float(shot_count - 1))
		var shot_angle: float = rotation + spread_offset
		var projectile: Projectile = firing_scene.instantiate() as Projectile
		if projectile == null:
			Log.error("Weapon projectile scene root must use Projectile.gd", firing_scene.resource_path)
			continue
		projectile.rotation = shot_angle
		projectile.velocity = Vector2.RIGHT.rotated(shot_angle) * projectile_speed
		projectile.damage = projectile_damage
		projectile.team = team
		projectile.source = self
		SectorSpace.spawn_owned(projectile, muzzle.global_position)
		if EventAudio.instance != null:
			EventAudio.instance.play_2d("enemy_fire" if team != 0 else "player_fire", self, "SFX")


## Equip a registered weapon by stable ID. Returns false without changing state on failure.
func equip_weapon(weapon_id: StringName, announce: bool = true) -> bool:
	var next_weapon: WeaponDefinition = RunState.get_weapon(weapon_id)
	if next_weapon == null or next_weapon.projectile_scene == null:
		Log.error("Cannot equip missing or incomplete weapon", weapon_id)
		return false
	weapon_definition = next_weapon
	active_weapon_id = next_weapon.weapon_id
	projectile_scene = next_weapon.projectile_scene
	_rebuild_stats(false)
	weapon_changed.emit(weapon_definition)
	if announce:
		Log.info("Weapon equipped", name, weapon_definition.display_name)
	return true


## Apply nonnegative damage to shields first, then hull; emits change and death signals.
func take_damage(amount: float) -> void:
	# Damage is absorbed by shields first; only overflow reaches hull.
	if is_dead or amount <= 0.0 or (team == 0 and god_mode):
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
	if hull_visual != null and is_instance_valid(hull_visual):
		Juicee.flash(hull_visual, Color(1.0, 0.75, 0.8), 0.08)
	if team == 0:
		if GameSettings.screen_shake_strength > 0.0:
			Juicee.shake_camera(self, 5.0 * GameSettings.screen_shake_strength, 0.16, 22.0)
		if EventAudio.instance != null:
			EventAudio.instance.play_2d("player_hull_hit", self, "SFX")
	elif GameSettings.screen_shake_strength > 0.0:
		Juicee.shake_camera(self, 0.7 * GameSettings.screen_shake_strength, 0.055, 32.0)
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
	if module == null or unequipped_modules.size() >= UNEQUIPPED_MODULE_CAPACITY:
		Log.warn("Unequipped module inventory is full", UNEQUIPPED_MODULE_CAPACITY)
		return false

	unequipped_modules.append(module)
	modules_changed.emit()
	Log.info("Module added to unequipped inventory", module.display_name, unequipped_modules.size())
	return true


## Move a reserve module into an available equipment slot and apply its stats.
## A slot index may be supplied to preserve the position selected by drag-and-drop.
func equip_module(inventory_index: int, equipped_slot_index: int = -1) -> bool:
	if inventory_index < 0 or inventory_index >= unequipped_modules.size():
		return false
	if installed_modules.size() >= module_slots:
		return false
	var requested_index: int = installed_modules.size() if equipped_slot_index < 0 else equipped_slot_index
	if requested_index < 0 or requested_index >= module_slots:
		return false
	var target_index: int = mini(requested_index, installed_modules.size())

	var module: ModuleDefinition = unequipped_modules[inventory_index]
	unequipped_modules.remove_at(inventory_index)
	installed_modules.insert(target_index, module)
	_rebuild_stats(false)
	modules_changed.emit()
	Log.info("Module equipped from inventory", module.display_name)
	return true


## Exchange an equipped module with a reserve module without changing either store's size.
func swap_equipped_with_reserve(equipped_index: int, reserve_index: int) -> bool:
	if equipped_index < 0 or equipped_index >= installed_modules.size():
		return false
	if reserve_index < 0 or reserve_index >= unequipped_modules.size():
		return false

	var equipped_module: ModuleDefinition = installed_modules[equipped_index]
	installed_modules[equipped_index] = unequipped_modules[reserve_index]
	unequipped_modules[reserve_index] = equipped_module
	_rebuild_stats(false)
	modules_changed.emit()
	Log.info("Equipped and reserve modules swapped", equipped_module.display_name, reserve_index)
	return true


## Move an equipped module to reserve and rebuild stats without that module.
func unequip_module(equipped_index: int) -> bool:
	if equipped_index < 0 or equipped_index >= installed_modules.size():
		return false
	if unequipped_modules.size() >= UNEQUIPPED_MODULE_CAPACITY:
		Log.warn("Cannot unequip module: reserve inventory is full", UNEQUIPPED_MODULE_CAPACITY)
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

	weapon_cooldown = weapon_definition.cooldown if weapon_definition != null else FALLBACK_WEAPON_COOLDOWN
	projectile_speed = weapon_definition.projectile_speed if weapon_definition != null else FALLBACK_PROJECTILE_SPEED
	projectile_damage = weapon_definition.damage if weapon_definition != null else FALLBACK_PROJECTILE_DAMAGE

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
	if team == 0:
		Juicee.preset_death(self)
	died.emit(self)
	queue_free()
