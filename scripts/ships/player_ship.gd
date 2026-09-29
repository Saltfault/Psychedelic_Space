extends BaseShip
## Player-controlled BaseShip; reads input and applies the selected pilot ability.
class_name PlayerShip

const PILOTS: Registry = preload("res://assets/data/registries/pilots.tres")

@export_custom(
	Registry.PROPERTY_HINT_CUSTOM,
	"res://assets/data/registries/pilots.tres,true",
) var pilot_id: StringName = &"dash"

var pilot: PilotDefinition = null
var pilot_cooldown_left: float = 0.0
var engine_flame_frame_time: float = 0.0

@onready var engine_flame: Sprite2D = $Visuals/EngineFlame


func _ready() -> void:
	if pilot_id != &"":
		pilot = PILOTS.load_entry(pilot_id) as PilotDefinition

	if pilot == null:
		Log.warn("YARD could not load PilotDefinition ID", pilot_id)
	else:
		Log.info("Pilot definition loaded", pilot_id, pilot.display_name)

	team = 0
	super._ready()


func _process(delta: float) -> void:
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


func _gather_commands(delta: float) -> void:
	pilot_cooldown_left = max(pilot_cooldown_left - delta, 0.0)

	var controller_aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

	if controller_aim.length() > 0.2:
		command_heading = controller_aim.normalized()
	else:
		var mouse_delta := (get_global_mouse_position() - global_position)

		if mouse_delta.length_squared() > 1.0:
			command_heading = mouse_delta.normalized()

	command_thrust = Input.get_action_strength("thrust")
	# Holding fire lets BaseShip's weapon cooldown control the firing rate.
	command_fire = Input.is_action_pressed("fire")

	if Input.is_action_just_pressed("pilot_ability"):
		_try_use_pilot_ability()


func _try_use_pilot_ability() -> void:
	if pilot == null:
		return

	if pilot_cooldown_left > 0.0:
		return

	match pilot.ability:
		PilotDefinition.ActiveAbility.DASH:
			# Add the configured impulse along the ship's right-facing forward axis.
			var forward := Vector2.RIGHT.rotated(rotation)
			velocity += forward * pilot.dash_impulse
			pilot_cooldown_left = pilot.cooldown
			Log.info("Pilot dash used", pilot.display_name, pilot.dash_impulse)


func get_pilot_cooldown_ratio() -> float:
	if pilot == null or pilot.cooldown <= 0.0:
		return 0.0

	return clamp(pilot_cooldown_left / pilot.cooldown, 0.0, 1.0)
