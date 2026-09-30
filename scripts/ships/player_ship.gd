extends BaseShip
## Player-controlled BaseShip; reads input and applies the selected pilot ability.
class_name PlayerShip

const PILOTS: Registry = preload("res://assets/data/registries/pilots.tres")

@export_custom(
	Registry.PROPERTY_HINT_CUSTOM,
	"res://assets/data/registries/pilots.tres,true",
) var pilot_id: StringName = &"dash"

var pilot: PilotDefinition = null
## When enabled by the developer console, player damage is ignored.
var god_mode: bool = false
var pilot_cooldown_left: float = 0.0
# Counts down the temporary faster-than-cruise movement cap.
var dash_time_left: float = 0.0
var engine_flame_frame_time: float = 0.0

@onready var engine_flame: Sprite2D = $Visuals/EngineFlame
@onready var camera: Camera2D = $Camera2D

var camera_rest_offset: Vector2 = Vector2.ZERO
var camera_shake_time_left: float = 0.0
var camera_shake_strength: float = 0.0


func _ready() -> void:
	if pilot_id != &"":
		pilot = PILOTS.load_entry(pilot_id) as PilotDefinition

	if pilot == null:
		Log.warn("YARD could not load PilotDefinition ID", pilot_id)
	else:
		Log.info("Pilot definition loaded", pilot_id, pilot.display_name)

	team = 0
	super._ready()
	camera_rest_offset = camera.offset


func take_damage(amount: float) -> void:
	if god_mode:
		return
	super.take_damage(amount)
	if amount > 0.0:
		camera_shake_time_left = 0.16
		camera_shake_strength = 5.0 * GameSettings.screen_shake_strength


## Kill the player even while God Mode is active; reserved for the explicit dev kill command.
func debug_kill() -> void:
	god_mode = false
	super.take_damage(hull + shield + 1.0)


func _process(delta: float) -> void:
	_update_camera_shake(delta)
	# Animate the imported 16-frame plume only while the player is thrusting.
	if command_thrust <= 0.0:
		engine_flame.visible = false
		engine_flame.frame = 0
		engine_flame_frame_time = 0.0
		return

	engine_flame.visible = true
	engine_flame_frame_time += delta
	while engine_flame_frame_time >= 1.0 / 24.0:
		engine_flame_frame_time -= 1.0 / 24.0
		engine_flame.frame = (engine_flame.frame + 1) % 16


func _update_camera_shake(delta: float) -> void:
	if camera_shake_time_left > 0.0 and GameSettings.screen_shake_strength > 0.0:
		camera_shake_time_left = maxf(camera_shake_time_left - delta, 0.0)
		var fade: float = camera_shake_time_left / 0.16
		var amplitude: float = camera_shake_strength * fade
		camera.offset = camera_rest_offset + Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude),
		)
	else:
		camera_shake_time_left = 0.0
		camera.offset = camera_rest_offset


func _gather_commands(delta: float) -> void:
	pilot_cooldown_left = max(pilot_cooldown_left - delta, 0.0)
	dash_time_left = maxf(dash_time_left - delta, 0.0)

	var controller_aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

	if controller_aim.length() > 0.2:
		command_heading = controller_aim.normalized()
	else:
		var mouse_delta := (get_global_mouse_position() - global_position)

		if mouse_delta.length_squared() > 1.0:
			command_heading = mouse_delta.normalized()

	command_thrust = Input.get_action_strength("thrust")
	# Holding fire lets BaseShip's weapon cooldown control the firing rate.
	command_fire = GameSettings.auto_fire or Input.is_action_pressed("fire")

	if Input.is_action_just_pressed("pilot_ability"):
		_try_use_pilot_ability()


func _try_use_pilot_ability() -> void:
	if pilot == null:
		return

	if pilot_cooldown_left > 0.0:
		return

	match pilot.ability:
		PilotDefinition.ActiveAbility.DASH:
			# Use the pilot's authored target speed along the ship's forward axis.
			var forward := Vector2.RIGHT.rotated(rotation)
			velocity = forward * pilot.dash_speed
			dash_time_left = pilot.dash_duration
			pilot_cooldown_left = pilot.cooldown
			Log.info("Pilot dash used", pilot.display_name, pilot.dash_speed)


func get_pilot_cooldown_ratio() -> float:
	if pilot == null or pilot.cooldown <= 0.0:
		return 0.0

	return clamp(pilot_cooldown_left / pilot.cooldown, 0.0, 1.0)


## Override the base cap only while the Dash impulse is active.
func _movement_speed_limit() -> float:
	if dash_time_left > 0.0 and pilot != null:
		return maxf(max_speed, pilot.dash_speed)
	return max_speed
