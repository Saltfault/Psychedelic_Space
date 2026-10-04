extends BaseShip
## Player-controlled BaseShip; reads input and applies the selected pilot ability.
class_name PlayerShip

@export var pilot_id: StringName = &"dash"

var pilot: PilotDefinition = null
## When enabled by the developer console, player damage is ignored.
var god_mode: bool = false
var pilot_cooldown_left: float = 0.0
# Counts down the temporary faster-than-cruise movement cap.
var dash_time_left: float = 0.0
var engine_flame_frame_time: float = 0.0

@onready var engine_flame: Sprite2D = $Visuals/EngineFlame
@onready var ram_shield: RamShield = $RamShield



func _ready() -> void:
	if RunState.selected_ship_id != &"":
		ship_id = RunState.selected_ship_id
	if RunState.selected_pilot_id != &"":
		pilot_id = RunState.selected_pilot_id
	if pilot_id != &"":
		pilot = RunState.get_pilot(pilot_id)

	if pilot == null:
		Log.warn("YARD could not load PilotDefinition ID", pilot_id)
	else:
		Log.info("Pilot definition loaded", pilot_id, pilot.display_name)

	team = 0
	super._ready()
	if pilot != null:
		ram_shield.configure(pilot)


func take_damage(amount: float) -> void:
	if god_mode:
		return
	var was_dead: bool = is_dead
	super.take_damage(amount)
	if amount > 0.0:
		if GameSettings.screen_shake_strength > 0.0:
			Juicee.shake_camera(self, 5.0 * GameSettings.screen_shake_strength, 0.16, 22.0)
		if EventAudio.instance != null:
			EventAudio.instance.play_2d("player_hull_hit", self, "SFX")
	if not was_dead and is_dead:
		Juicee.preset_death(self)


## Kill the player even while God Mode is active; reserved for the explicit dev kill command.
func debug_kill() -> void:
	god_mode = false
	super.take_damage(hull + shield + 1.0)


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
	var is_ram: bool = pilot.ability == PilotDefinition.ActiveAbility.RAM_SHIELD
	if (not is_ram and pilot_cooldown_left > 0.0) or (is_ram and ram_shield.current_health < pilot.ram_activation_cost):
		return

	match pilot.ability:
		PilotDefinition.ActiveAbility.DASH:
			# Use the pilot's authored target speed along the ship's forward axis.
			var forward := Vector2.RIGHT.rotated(rotation)
			velocity = forward * pilot.dash_speed
			dash_time_left = pilot.dash_duration
			pilot_cooldown_left = pilot.cooldown
			if GameSettings.screen_shake_strength > 0.0:
				Juicee.shake_camera(self, 1.8 * GameSettings.screen_shake_strength, 0.11, 28.0)
			Log.info("Pilot dash used", pilot.display_name, pilot.dash_speed)
			if EventAudio.instance != null:
				EventAudio.instance.play_2d("player_dash", self, "SFX")
		PilotDefinition.ActiveAbility.RAM_SHIELD:
			if not ram_shield.activate(pilot):
				return
			if GameSettings.screen_shake_strength > 0.0:
				Juicee.shake_camera(self, 1.2 * GameSettings.screen_shake_strength, 0.1, 24.0)
			Log.info("Ram shield activated", pilot.display_name, ram_shield.get_charge_ratio())


func get_pilot_cooldown_ratio() -> float:
	if pilot == null:
		return 0.0
	if pilot.ability == PilotDefinition.ActiveAbility.RAM_SHIELD:
		return ram_shield.get_charge_ratio()
	if pilot.cooldown <= 0.0:
		return 0.0

	return clamp(pilot_cooldown_left / pilot.cooldown, 0.0, 1.0)


## Override the base cap only while the Dash impulse is active.
func _movement_speed_limit() -> float:
	if dash_time_left > 0.0 and pilot != null:
		return maxf(max_speed, pilot.dash_speed)
	return max_speed
